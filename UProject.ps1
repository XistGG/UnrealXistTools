#!/usr/bin/env pwsh
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

# Add an internal "_UProjectFile" property containing the absolute path to this .uproject
# This begins with an underscore in case you decide to serialize this object later, you
# should discard any/all property names beginning with an underscore.
$UProject | Add-Member -MemberType NoteProperty -Name "_UProjectFile" -Value $UProjectFile.FullName

return $UProject
