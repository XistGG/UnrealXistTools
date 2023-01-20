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
    Write-Debug "Compute UProjectFile Path=$Path"
    $UProjectFile = & $PSScriptRoot/UProjectFile.ps1 -Path $Path
}
else
{
    # No path is selected, use the default
    Write-Debug "Compute Default UProjectFile"
    $UProjectFile = & $PSScriptRoot/UProjectFile.ps1
}


# Do not continue without a valid $UProjectFile

if (!$UProjectFile -or !$UProjectFile.Exists)
{
    throw "Path is not a UProject: $Path"
}


# Parse the $UProjectFile JSON

$UProject = Get-Content -Raw $UProjectFile.FullName | ConvertFrom-Json

if (!$UProject)
{
    throw "Invalid .uproject data: $UProjectFile"
}

return $UProject
