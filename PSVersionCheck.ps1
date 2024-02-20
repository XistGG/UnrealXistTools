#!/usr/bin/env pwsh
#
# PSVersionCheck.ps1
#
# UnrealXistTools requires PowerShell 7+.
#
# Including this script in others will cause an exception to be thrown
# with an appropriate error message if/when the script is being executed
# in a PowerShell context that does not support the minimum version.
#

$MinPSVersion = 7

if ($MinPSVersion -gt $PSVersionTable.PSVersion.Major) {
    Write-Error "This system is using PowerShell version $($PSVersionTable.PSVersion.Major), which is not adequate to run UnrealXistTools."
    throw "Powershell $($MinPSVersion)+ is required. Install it with 'winget install Microsoft.PowerShell'"
}
