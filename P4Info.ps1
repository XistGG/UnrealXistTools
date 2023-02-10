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
#

[CmdletBinding()]
param (
    [switch] $Config
)


# Read p4 info
$P4Output = p4 info

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
