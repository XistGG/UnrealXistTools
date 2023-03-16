# 
# UProjectSln.ps1
#
# See: https://github.com/XistGG/UnrealXistTools/
#
# This takes an optional $Path value and expands it to an actual
# MyGame.sln file location.
#
# If $Path does not expand to a valid .sln file,
# an exception is thrown.
#
# If no exception is thrown, the Get-Item result for the .sln is returned
#
# Usage: UProjectSln.ps1 -Debug
#

[CmdletBinding()]
param(
    [Parameter()]$Path
)


function FindSlnInDirectory()
{
    param(
        [string]$ProjectName,
        [string]$Directory
    )

    $Result = $null
    $TempSlns = Get-ChildItem -Path $Directory -File `
        | Where-Object {$_.Extension -ieq '.sln'}

    if ($TempSlns.count -eq 1)
    {
        # Found exactly 1 .sln file, use it
        $Result = $TempSlns[0]

        Write-Debug "Found 1 .sln in $Directory, using it: $Result"
    }
    elseif ($TempSlns.count -gt 1)
    {
        # $UProjectSln is a directory with multiple .sln files

        # Search for a project file with the same name as the directory
        foreach ($ProjectSln in $TempSlns)
        {
            if ($ProjectName -ieq $ProjectSln.BaseName)
            {
                # Found it (example "Foo/Foo.sln")
                $Result = $ProjectSln
                Write-Debug "Compare '$ProjectName' -ieq '$($ProjectSln.BaseName)' == TRUE"
            }
            else
            {
                Write-Debug "Compare '$ProjectName' -ieq '$($ProjectSln.BaseName)' == false"
            }
        }

        # If we still don't know which .sln to start, error.
        # User needs to tell us explicitly.

        if (!$Result)
        {
            foreach ($ProjectSln in $TempSlns)
            {
                Write-Warning "Ambiguous .sln: $ProjectSln"
            }

            Write-Error "Cannot auto-select a .sln file in a directory with multiple .sln; You must specify which .sln to use for this directory"
            throw "Explicit uproject required for directory: $Directory"
        }

        Write-Debug "Found 2+ .sln in $Directory, using: $Result"
    }
    else # $TempSlns.count -lte 0
    {
        # $UProjectSln is a directory without any .sln files
        throw "Not an Unreal Engine project directory; no .sln files in: $Directory"
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
$SlnItem = Get-Item -Path $Path 2> $null

if (!$SlnItem -or !$SlnItem.Exists)
{
    throw "No such UProject file or directory: $Path"
}

# First check of $UProjectSln is a file
if (!$SlnItem.PSIsContainer)
{
    # $SlnItem is a file; make sure it has a .sln extension
    if (!($SlnItem.Extension -ieq '.sln'))
    {
        throw "Sln is not a .sln: $Path"
    }

    Write-Debug "SlnItem is a .sln file; using it: $($SlnItem.FullName)"
}
else
{
    # $SlnItem is a directory, try to find the correct .sln to use
    $SlnItem =& FindSlnInDirectory -ProjectName $SlnItem.Name -Directory $SlnItem.FullName

    # We expect an exception will already have been thrown when !$SlnItem,
    # but just to drive this point, here it is explicitly:
    if (!$SlnItem) { throw "SlnItem is null" };
}


Write-Debug "SlnItem=$SlnItem"

return $SlnItem
