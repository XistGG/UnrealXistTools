#!/usr/bin/env pwsh
#
# P4FStat.ps1
#
#   Run `p4 fstat` on the list of files you provide to -Path
#
#   Returns an array of objects containing the result
#

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [object]$Path
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

# Import the P4 helper module
Import-Module -Name $PSScriptRoot/Modules/P4.psm1


# Convert $Path from string to array if needed
if ($Path -is [string])
{
    $Path = @($Path)
}

if (-not ($Path -is [array]))
{
    throw "-Path argument must be a string or an array"
}

&P4_FStat -Paths $Path
