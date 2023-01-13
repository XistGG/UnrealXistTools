# 
# UProjectFile.ps1
#
# See: https://github.com/XistGG/UnrealXistTools/
#
# This is an include file.  It takes an optionally set
# $UProjectFile value and expands it to an actual MyGame.uproject
# file location.
#
# The value you pass in can be:
#
# (empty) -> '.'
# '../MyGame.uproject'
# '../MyGame' # (same as '../MyGame/MyGame.uproject')
#
# If the passed in value does not expand to a valid uproject file,
# an exception is thrown.
#
# If no exception is thrown, these variables will be set:
#
# $UProjectFile = absolute path to MyGame.uproject
# $UProjectDirectory = absolute path to MyGame.uproject parent directory
#

if (!$UProjectFile)  # if $null, '' or any other empty value
{
    # Default implicit $UProjectFile location is current directory
    $UProjectFile = Get-Location

    if (!$Quiet)
    {
        Write-Host "Auto-selecting project in directory: $(Get-Location)"
    }
}

# Try to get information about the UProject (file or directory)
$UProjectItem = Get-Item -Path $UProjectFile 2> $null

if (!$UProjectItem.Exists)
{
    throw "No such UProject file or directory: $UProjectFile"
}

# First check of $UProjectFile is a file
if (!$UProjectItem.PSIsContainer)
{
    if ($UProjectItem.Extension -ieq '.uproject')
    {
        # Expand this file to its absolute path
        $UProjectFile = $UProjectItem.FullName
    }
    else
    {
        throw "File is not a .uproject: $UProjectFile"
    }
}
else
{
    # $UProjectItem is a directory with 0+ .uproject files
    #
    #     like "MyGame/MyGame.uproject"
    #       or "MyGame/Other.uproject"
    #       or "MyGame/YetAnother.uproject"

    # Find all .uproject files in the directory

    $TempProjects = Get-ChildItem -Path $UProjectItem.FullName `
        | Where-Object {!$_.PSIsContainer -and ($_.Extension -ieq '.uproject') }

    if ($TempProjects.count -eq 1)
    {
        # Found exactly 1 .uproject file, use it
        $UProjectItem = $TempProjects[0]
    }
    elseif ($TempProjects.count -gt 1)
    {
        # $UProjectFile is a directory with multiple .uproject files

        $FoundUProject = $false

        # Search for a project file with the same name as the directory
        foreach ($ProjectFile in $TempProjects)
        {
            if ($UProjectItem.Name -ieq $ProjectFile.BaseName)
            {
                # Found it (example "Foo/Foo.uproject")
                $UProjectItem = $ProjectFile
                $FoundUProject = $true
                break;
            }
        }

        # If we still don't know which .uproject to start, error
        # User needs to tell us explicitly.

        if (!$FoundUProject)
        {
            foreach ($ProjectFile in $TempProjects)
            {
                Write-Warning "Ambiguous .uproject: $ProjectFile"
            }

            Write-Error "Cannot auto-select a .uproject file in a directory with multiple .uproject; You must specify which .uproject to use for this directory"
            throw "Explicit uproject required for directory: $UProjectItem"
        }
    }
    else # $TempProjects.count -lte 0
    {
        # $UProjectFile is a directory without any .uproject files
        throw "Not an Unreal Engine project directory; no .uproject files in: $UProjectItem"
    }
}


$UProjectFile = $UProjectItem.FullName
$UProjectDirectory = $UProjectItem.Directory.FullName


if (!$Quiet)
{
    Write-Host ""
    Write-Host "UProjectFile=$UProjectFile"
    Write-Host "UProjectDirectory=$UProjectDirectory"
    Write-Host ""
}
