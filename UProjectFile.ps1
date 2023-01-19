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
# $UProjectDirectory = absolute path to MyGame.uproject parent directory
# $UProjectFile = absolute path to MyGame.uproject
# $UProjectItem = Get-Item -Path $UProjectFile
#

[CmdletBinding()]
param(
    [switch]$Quiet,
    [Parameter()]$UProjectFile
)


function FindUProjectInDirectory()
{
    param(
        [string]$ProjectName,
        [string]$Directory
    )

    $Result = $null
    $TempProjects = Get-ChildItem -Path $Directory -File `
        | Where-Object {$_.Extension -ieq '.uproject'}

    if ($TempProjects.count -eq 1)
    {
        # Found exactly 1 .uproject file, use it
        $Result = $TempProjects[0]

        Write-Debug "Found 1 .uproject in $Directory, using it: $Result"
    }
    elseif ($TempProjects.count -gt 1)
    {
        # $UProjectFile is a directory with multiple .uproject files

        # Search for a project file with the same name as the directory
        foreach ($ProjectFile in $TempProjects)
        {
            if ($ProjectName -ieq $ProjectFile.BaseName)
            {
                # Found it (example "Foo/Foo.uproject")
                $Result = $ProjectFile
                Write-Debug "Compare '$ProjectName' -ieq '$($ProjectFile.BaseName)' == TRUE"
            }
            else
            {
                Write-Debug "Compare '$ProjectName' -ieq '$($ProjectFile.BaseName)' == false"
            }
        }

        # If we still don't know which .uproject to start, error.
        # User needs to tell us explicitly.

        if (!$Result)
        {
            foreach ($ProjectFile in $TempProjects)
            {
                Write-Warning "Ambiguous .uproject: $ProjectFile"
            }

            Write-Error "Cannot auto-select a .uproject file in a directory with multiple .uproject; You must specify which .uproject to use for this directory"
            throw "Explicit uproject required for directory: $Directory"
        }

        Write-Debug "Found 2+ .uproject in $Directory, using: $Result"
    }
    else # $TempProjects.count -lte 0
    {
        # $UProjectFile is a directory without any .uproject files
        throw "Not an Unreal Engine project directory; no .uproject files in: $Directory"
    }

    return $Result
}



################################################################################
##  Main
################################################################################

if (!$UProjectFile)  # if $null, '' or any other empty value
{
    # Default implicit $UProjectFile location is current directory
    $UProjectFile = Get-Location

    Write-Debug "Auto-selecting project in directory: $(Get-Location)"
}

# Try to get information about the UProject (file or directory)
$UProjectItem = Get-Item -Path $UProjectFile 2> $null

if (!$UProjectItem -or !$UProjectItem.Exists)
{
    throw "No such UProject file or directory: $UProjectFile"
}

# First check of $UProjectFile is a file
if (!$UProjectItem.PSIsContainer)
{
    # $UProjectItem is a file; make sure it has a .uproject extension
    if (!($UProjectItem.Extension -ieq '.uproject'))
    {
        throw "File is not a .uproject: $UProjectFile"
    }

    Write-Debug "UProjectFile is a .uproject file; using it: $($UProjectItem.FullName)"
}
else
{
    # $UProjectItem is a directory, try to find the correct .uproject to use
    $UProjectItem = &FindUProjectInDirectory -ProjectName $UProjectItem.Name -Directory $UProjectItem.FullName
    # We expect an exception will already have been thrown when !$UProjectItem,
    # but just to drive this point, here it is explicitly:
    if (!$UProjectItem) { throw "UProjectItem is null" };
}


$UProjectFile = $UProjectItem.FullName
$UProjectDirectory = $UProjectItem.Directory


if (!$Quiet)
{
    Write-Host "UProjectFile=$UProjectFile"
    Write-Host "UProjectDirectory=$UProjectDirectory"
}
