#!/usr/bin/env pwsh
#
# P4FilterIgnored.ps1
#
#   Split all the paths into 2 groups: Ignored and Not-Ignored
#
# Example Usage:
#
#   ## In your Project directory:
#   $result = P4FilterIgnored.ps1 $(Get-ChildItem Config,Plugins,Source -Force -Recurse -File)
#
#   $result.ValidPaths | %{ Write-Output "Do something with $_" }
#
#   $result.ValidPaths.Count
#   $result.IgnoredPaths.Count
#

[CmdletBinding()]
    param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Paths
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

# Import the P4 helper module
Import-Module -Name $PSScriptRoot/Modules/P4.psm1


& P4_FilterIgnoredPaths -Paths $Paths
