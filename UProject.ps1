#
# UProject.ps1
#
# Object containing JSON-parsed contents of a .uproject
#

[CmdletBinding()]
param(
    [Parameter()]$Path
)


################################################################################
##  Main
################################################################################

if ($Path)
{
    Write-Debug "Path=$Path"

    . $PSScriptRoot/UProjectFile.ps1 -Path $Path
}
else
{
    # No path is selected, use the default
    Write-Debug "Computing Default UProjectFile"
    . $PSScriptRoot/UProjectFile.ps1
}


# Do not continue without a valid $UProjectFile

if (!$UProjectFile)
{
    throw "Path is not a UProject: $Path"
}


# Parse the $UProjectFile JSON

$UProject = Get-Content -Raw $UProjectFile | ConvertFrom-Json

return $UProject
