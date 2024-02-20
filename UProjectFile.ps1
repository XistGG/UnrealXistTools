#!/usr/bin/env pwsh
#
# UProjectFile.ps1
#
# See: https://github.com/XistGG/UnrealXistTools/
#
# This takes an optional $Path value and expands it to an actual
# MyGame.uproject file location.
#
# If $Path does not expand to a valid .uproject file,
# an exception is thrown.
#
# If no exception is thrown, these variables will be set:
#
# $UProjectDirectory = the absolute path to MyGame.uproject parent directory
# $UProjectFile      = the absolute path to MyGame.uproject
# $UProjectFileItem  = Get-Item -Path $UProjectFile
#

[CmdletBinding()]
param(
    [Parameter()]$Path
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

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

if (!$Path)  # if $null, '' or any other empty value
{
    # Default implicit $Path is current directory
    $Path = Get-Location

    Write-Debug "Auto-selecting current directory Path: $Path"
}

# Try to get information about the UProject (file or directory)
$UProjectFileItem = Get-Item -Path $Path 2> $null

if (!$UProjectFileItem -or !$UProjectFileItem.Exists)
{
    throw "No such UProject file or directory: $Path"
}

# First check of $UProjectFile is a file
if (!$UProjectFileItem.PSIsContainer)
{
    # $UProjectFileItem is a file; make sure it has a .uproject extension
    if (!($UProjectFileItem.Extension -ieq '.uproject'))
    {
        throw "File is not a .uproject: $Path"
    }

    Write-Debug "UProjectFile is a .uproject file; using it: $($UProjectFileItem.FullName)"
}
else
{
    # $UProjectFileItem is a directory, try to find the correct .uproject to use
    $UProjectFileItem = &FindUProjectInDirectory -ProjectName $UProjectFileItem.Name -Directory $UProjectFileItem.FullName

    # We expect an exception will already have been thrown when !$UProjectFileItem,
    # but just to drive this point, here it is explicitly:
    if (!$UProjectFileItem) { throw "UProjectItem is null" };
}


$UProjectFile = $UProjectFileItem

Write-Debug "UProjectFile=$UProjectFile"

return $UProjectFile
