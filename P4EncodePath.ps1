#!/usr/bin/env pwsh
#
# P4EncodePath.ps1
#
#    Encode (or Decode) a path for P4.
#
#    @see https://www.perforce.com/manuals/cmdref/Content/CmdRef/filespecs.html
#

[CmdletBinding()]
param(
    [switch]$Decode,
    [switch]$Help,
    [switch]$Test,
    [Parameter()]$Path
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

# Import the P4 helper module
Import-Module -Name $PSScriptRoot/Modules/P4.psm1

$ThisScript = $MyInvocation.MyCommand.Path
$ScriptName = $MyInvocation.MyCommand.Name
$ScaryPath = "//tmp/scary/name/! -+ 's #%25*:@"


function GetHelpOutput()
{
    [CmdletBinding()]
    $EncodedScaryPath =& $ThisScript -Path $ScaryPath
    return @"

############################################################
##
##  Usage for ${ScriptName}:
##

& $ScriptName -Path "$ScaryPath"

    Encode the Path.  Writes text to stdout.

& $ScriptName -Decode -Path "$EncodedScaryPath"

    Decode the Path.  Writes text to stdout.

& $ScriptName -Test

    Test encoding and decoding accuracy.

& $ScriptName -Help

    Display this help.

"@
}

if ($Help)
{
    return &GetHelpOutput
}


################################################################################
##  Test
################################################################################

if ($Test)
{
    $EncodedScaryPath =& P4_EncodePath $ScaryPath
    $DecodedEncoded =& P4_DecodePath $EncodedScaryPath

    Write-Host "Starting Path: $ScaryPath"
    Write-Host "Encoded Path: $EncodedScaryPath"
    Write-Host "Decoded Encoded: $DecodedEncoded"

    if (!($ScaryPath -ceq $DecodedEncoded))
    {
        Write-Error "Decoded Encoded is not identical to Starting Path"
        throw "Encoding/Decoding Validation Failed"
    }

    Write-Host "Test success: Starting filename == Decoded Encoded"

    return;
}


################################################################################
##  Main
################################################################################

if (!$Path)
{
    GetHelpOutput | Write-Warning
    return
}

$Result = $null

if ($Decode)
{
    $Result =& P4_DecodePath $Path
}
else
{
    $Result =& P4_EncodePath $Path
}

return $Result
