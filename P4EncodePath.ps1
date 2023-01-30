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

$ThisScript = $MyInvocation.MyCommand.Path
$ScriptName = $MyInvocation.MyCommand.Name
$ScaryPath = "//tmp/scary/name/! -+ 's #%*:@"


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
    $EncodedScaryPath =& $ThisScript -Path $ScaryPath
    $DecodedEncoded =& $ThisScript -Decode -Path $EncodedScaryPath

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
    # `p4 add -m` writes filenames in an Encoded format, so we need to decode it
    $Result = $Path -ireplace '%23','#' `
                    -ireplace '%25','%' `
                    -ireplace '%2A','*' `
                    -ireplace '%3A',':' `
                    -ireplace '%40','@'
}
else
{
    # MUST ENCODE '%' CHARACTER BEFORE ANY OTHER !!
    $Result = $Path -ireplace '%','%25' `
                    -ireplace '#','%23' `
                    -ireplace '\*','%2A' `
                    -ireplace ':','%3A' `
                    -ireplace '@','%40'
}

return $Result
