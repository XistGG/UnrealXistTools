#
# UProject.ps1
#
# Object containing JSON-parsed contents of a .uproject
#

[CmdletBinding()]
param(
    [Parameter()]$Path
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

################################################################################
##  Main
################################################################################

Write-Debug "Compute UProjectFile Path=[$Path]"
$UProjectFile =& $PSScriptRoot/UProjectFile.ps1 -Path:$Path

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
