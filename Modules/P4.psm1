#
# P4.psm1
#

function P4_DecodePath
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    # MUST DECODE '%' CHARACTER AFTER ALL OTHERS !!
    # @see https://www.perforce.com/manuals/cmdref/Content/CmdRef/filespecs.html
    $Path -ireplace '%23','#' `
          -ireplace '%2A','*' `
          -ireplace '%3A',':' `
          -ireplace '%40','@' `
          -ireplace '%25','%'
}

function P4_EncodePath
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    # MUST ENCODE '%' CHARACTER BEFORE ANY OTHER !!
    # the '*' line must be regex-escaped because asterisk is a special regex character
    # @see https://www.perforce.com/manuals/cmdref/Content/CmdRef/filespecs.html
    $Path -ireplace '%','%25' `
          -ireplace '#','%23' `
          -ireplace '\*','%2A' `
          -ireplace ':','%3A' `
          -ireplace '@','%40'
}

function P4_ParseChangeLine
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$Line
    )

    $Result = [PSCustomObject]@{
        IsChange = $false
        P4Path = $null
        Revision = $null
        Type = $null  # if non $null, one of "add", "edit" or "delete"
        Info = $null
    }

    if ($Line -match "^(//[^#]+)#(\d+) \- (\S+)\s+(.*)")
    {
        $Result.IsChange = $true
        $Result.P4Path =& P4_DecodePath $matches[1]
        $Result.Revision = $matches[2]
        $Result.Type = $matches[3]
        $Result.Info = $matches[4].TrimEnd(" ", "`r")  # Strip any spaces or CR characters from the end
    }

    $Result
}

Export-ModuleMember -Function P4_DecodePath, P4_EncodePath, P4_ParseChangeLine
