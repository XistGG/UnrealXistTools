#!/usr/bin/env pwsh
#
# P4NukeCL.ps1
#
#   Given a CL that contains a bunch of changes, completely nuke it
#   WITHOUT MODIFYING THE LOCAL FILES AT ALL.
#
#   This will revert P4's idea of how its internal database needs to change,
#   by unmarking all files for add/delete/change/etc, BUT IT WILL NOT CHANGE
#   THE FILES THEMSELVES.
#
#   This mainly serves as a reminder of how to do this.  :)
#

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [object]$CL
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1


function NukeCL
{
    param(
        [string] $CL
    )

    p4 revert -k -c $CL //...

    if ($CL -ne "default")
    {
        p4 change -d $CL
    }

    $null
}


if ($CL -is [string])
{
    &NukeCL -CL $CL
}
elseif ($CL -is [array])
{
    foreach ($cl in $CL)
    {
        &NukeCL -CL $cl
    }
}
else
{
    throw "-CL argument must be a string or an array"
}
