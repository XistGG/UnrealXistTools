#!/usr/bin/env pwsh
#
# Return P4 Info
#
# Returns the output of `p4 info` as a Dictionary, so you can easily
# extract p4 config from it:
#
#   $P4USER = (P4Info.ps1)."User name"
#
#   -Config switch causes `.p4config` contents to be written to stdout,
#           so you can for example `P4Info.ps1 -config > .p4config`
#   -Full switch causes a full query of p4 info, including items that
#         require database lookups.  Disabled by default.
#   -Debug switch shows extra debugging output to help diagnose problems.
#

[CmdletBinding()]
param (
    [switch] $Config,
    [switch] $Full
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

Write-Debug "Executing 'p4 info'..."

# Read p4 info (Full version or -s version)
$P4Output = $Full ? (p4 info) : (p4 info -s)

# Parse the output
$P4Info = New-Object "System.Collections.Generic.Dictionary[[string],[string]]"
foreach ($line in $P4Output)
{
    $k = $line -ireplace '^([^:]+):.*','$1'
    $v = $line -ireplace '^[^:]+:\s*(.*)','$1'
    Write-Debug "k='$k' v='$v'"
    $P4Info[$k] = $v
}


if ($Config -and $P4Info)
{
    $P4Config = New-Object "System.Collections.Generic.List[string]"

    if ($P4Info["User name"]) { [void] $P4Config.Add("P4USER=$($P4Info["User name"])") }
    if ($P4Info["Peer address"]) { [void] $P4Config.Add("P4PORT=$($P4Info["Peer address"])") }
    if ($P4Info["Client name"]) { [void] $P4Config.Add("P4CLIENT=$($P4Info["Client name"])") }

    return $P4Config -join [System.Environment]::NewLine
}

return $P4Info
