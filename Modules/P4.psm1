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
        Type = $null  # if non $null, one of "add", "edit", "delete", "integrate", ...
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

function P4_FilterIgnoredPaths
{
    param(
        [Parameter(Mandatory=$true)]
        [System.Collections.ArrayList]$Paths
    )

    $result = [PSCustomObject]@{
        ValidPaths = New-Object System.Collections.ArrayList
        IgnoredPaths = New-Object System.Collections.ArrayList
    }

    try {
        Write-Debug "EXEC: p4 ignores -i $($Paths -join ' ')"
        $output = p4 ignores -i @Paths

        $stdoutLines = $output -split "`r`n|`n|`r"
        $ignoredFiles = New-Object System.Collections.ArrayList

        # The file will only appear in the stdout if it should be ignored
        foreach ($line in $stdoutLines)
        {
            if ($line -imatch '^(.+\S)\s+ignored\s*$')
            {
                $p4name = $matches[1]
                $realPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p4name)
                $ignoredFiles.Add($realPath) > $null

                #Write-Debug "p4name  =$p4name"
                #Write-Debug "realPath=$realPath"
            }
        }

        if ($ignoredFiles.Count -eq 0)
        {
            # None of the paths should be ignored
            $result.ValidPaths = $Paths
            return $result
        }

        # At least one path should be ignored
        $ValidPaths = New-Object System.Collections.ArrayList
        $IgnoredPaths = New-Object System.Collections.ArrayList

        foreach ($path in $Paths)
        {
            $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($path)
            $isValid = $true

            foreach ($invalidFile in $ignoredFiles)
            {
                if ($fullPath -eq $invalidFile)
                {
                    $isValid = $false
                    break
                }
            }

            if ($isValid)
            {
                $result.ValidPaths.Add($path) > $null
            }
            else
            {
                $result.IgnoredPaths.Add($path) > $null
            }
        }

        return $result
    }
    catch {
        throw "Failed to execute p4 ignores: $_"
    }
}

function P4_GetPendingChangeLists
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$Workspace
    )

    $output = p4 changes -c $Workspace -s pending -r
    $lines = $output -split "`r`n|`n|`r"

    $changes = New-Object System.Collections.ArrayList

    foreach ($line in $lines)
    {
        # Line format is expected to be:
        # Change 123 on 2024/12/31 by user@workspace *pending* 'Change description (truncated)'

        if ($line -imatch '^Change\s+(\d+)\s+on\s+')
        {
            $cl = $matches[1]
            $changes.Add($cl) > $null
        }
    }

    return $changes
}

function P4_FStat
{
    param(
        [Parameter(Mandatory=$true)]
        [System.Collections.ArrayList] $Paths
    )

    Write-Debug "EXEC: p4 fstat $($Paths -join ' ')"
    $output = p4 fstat @Paths

    $lines = $output -split "`r`n|`n|`r"

    $result = New-Object System.Collections.ArrayList
    $isInFile = $false
    $lineNum = 0

    foreach ($line in $lines)
    {
        $lineNum += 1

        if ($line -match '^\.\.\. (\S+)\s*(.*)')
        {
            $key = $matches[1]
            $value = $matches[2]

            # p4 fstat intends for the presence of this property to mean that this property does exist
            # and is set. Checking for that in powershell is annoying, so we'll change the value to $true
            # so we can simply check if this property value is true rather than checking if it exists
            # as an empty string.
            if ($value -eq "")
            {
                $value = $true
            }

            if ($key -eq "depotFile" -and -not $isInFile)
            {
                # Starting a new file
                $isInFile = $true
                $fstat = [PSCustomObject]@{
                    $key = $value
                }
                continue
            }
            elseif ($isInFile)
            {
                # Continuing the existing file
                $fstat | Add-Member -Name $key -Type NoteProperty -Value $value
                continue
            }
        }
        elseif ($line -eq "")
        {
            $isInFile = $false
            $result.Add($fstat) > $null
            continue
        }

        throw "Unexpected p4 fstat output near line ${lineNum}: $line"
    }

    return $result
}

Export-ModuleMember -Function P4_DecodePath, P4_EncodePath, P4_ParseChangeLine
Export-ModuleMember -Function P4_FilterIgnoredPaths, P4_GetPendingChangeLists, P4_FStat
