#
# P4.psm1
#

class P4_Exception : System.Exception
{
    P4_Exception([string]$command, [int]$code)
      : base("P4 command failed with code ${code}: ${command}")
    {}
}

class P4_Parse_Exception : System.Exception
{
    P4_Parse_Exception([string]$message)
      : base($message)
    {}
}

function P4_DecodePath
{
    param(
        [Parameter(Mandatory=$true, Position=0)]
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
        [Parameter(Mandatory=$true, Position=0)]
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

function P4_ParseFileType
{
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$TypeString
    )

    $result = [PSCustomObject]@{
        RawType = $TypeString
        BaseType = $null
        ModString = $null
        Modifiers = [PSCustomObject]@{}
    }

    if ($TypeString -match "([^\+]+)(\+(.+))?")
    {
        $result.BaseType = $matches[1]
        $result.ModString = $matches[3]  # yes 3, not 2

        # Parse known modifiers
        # @see https://help.perforce.com/helix-core/server-apps/cmdref/current/Content/CmdRef/file.types.synopsis.modifiers.html

        if ($result.ModString -ne $null)
        {
            $tmp = $result.ModString

            # Parse all modifiers that take no arguments
            while ($tmp -match "(.*)([CDFlmwXx])(.*)")
            {
                $result.Modifiers | Add-Member -Name $matches[2] -Type NoteProperty -Value $true
                $tmp = $matches[1] + $matches[3]
            }

            # "k" and "ko" are mutually exclusive
            if ($tmp -match "(.*)(ko?)(.*)")
            {
                $result.Modifiers | Add-Member -Name $matches[2] -Type NoteProperty -Value $true
                $tmp = $matches[1] + $matches[3]
            }

            # "S" takes an optional integer argument that defaults to 1
            if ($tmp -match "(.*)S(\d*)(.*)")
            {
                $tmpName = 'S'
                $tmpValue = [Math]::Max(1, [int] $matches[2])
                $result.Modifiers | Add-Member -Name $tmpName -Type NoteProperty -Value $tmpValue
                $tmp = $matches[1] + $matches[3]
            }

            if ($tmp -ne "")
            {
                Write-Warning "P4.psm1: P4_ParseFileType: Invalid file type modifier `"$TypeString`" (unrecognized modifier: `"$tmp`")"
            }
        }
    }

    return $result
}

function P4_ParseChangeLine
{
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Line,
        [switch]$ParseFileType
    )

    $result = [PSCustomObject]@{
        IsFile = $false
        P4Path = $null
        Revision = $null
        Info = $null
    }

    if ($Line -match "^(//[^#]+)#(\d+) \- (.*)")
    {
        $result.IsFile = $true
        $result.P4Path =& P4_DecodePath $matches[1]
        $result.Revision = $matches[2]
        $result.Info = $matches[3].TrimEnd(" ", "`r")  # Strip any spaces or CR characters from the end

        if ($ParseFileType -and $result.Info -match ".*\((.+)\)$")
        {
            $typeResult =& P4_ParseFileType -TypeString $matches[1]
            $result | Add-Member -Name "FileType" -Type NoteProperty -Value $typeResult
        }
    }

    return $result
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
        $command = "p4 ignores -i $($Paths -join ' ')"
        Write-Debug "EXEC: $command"

        $output = p4 ignores -i @Paths

        if ($LASTEXITCODE -ne 0)
        {
            throw [P4_Exception]::new($command, $LASTEXITCODE)
        }

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
        throw
    }
}

function P4_GetPendingChangeLists
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$Workspace
    )

    $command = "p4 changes -c $Workspace -s pending -r"
    $output = p4 changes -c $Workspace -s pending -r

    if ($LASTEXITCODE -ne 0)
    {
        throw [P4_Exception]::new($command, $LASTEXITCODE)
    }

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

function internal_FStat
{
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [System.Collections.ArrayList] $Paths
    )

    $encodedPaths = New-Object System.Collections.ArrayList
    foreach ($path in $Paths)
    {
        $encodedPath = P4_EncodePath $path
        $encodedPaths.Add($encodedPath) > $null
    }

    $command = "p4 fstat $($encodedPaths -join ' ')"
    Write-Debug "EXEC: $command"

    $output = p4 fstat @encodedPaths

    if ($LASTEXITCODE -ne 0)
    {
        throw [P4_Exception]::new($command, $LASTEXITCODE)
    }

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

            if ($key -eq "depotFile")
            {
                # decode the path so application code doesn't need to worry about encoding/decoding
                # all the time, we just do it automatically
                $value = P4_DecodePath $value
            }

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

function P4_FStat
{
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [System.Collections.ArrayList] $Paths,
        [int] $MaxTries = 5,
        [int] $RetryInterval = 2
    )

    # Enforce a minimum $MaxTries of 1
    $MaxTries = [Math]::Max(1, $MaxTries)

    # Enforce a minimum retry interval of 1 second
    $RetryInterval = [Math]::Max(1, $RetryInterval)

    $numTries = 0
    while ($numTries -lt $MaxTries)
    {
        $numTries ++

        try
        {
            $result = internal_FStat $Paths
            return $result
        }
        catch [P4_Exception]
        {
            if ($numTries -ge $MaxTries)
            {
                Write-Error $_
                Write-Warning "Tried $numTries/$MaxTries times, giving up"

                # Propagate this exception, we've tried the max number of times
                throw
            }

            Write-Warning $_
            Write-Warning "Tried $numTries/$MaxTries times, will retry in $RetryInterval seconds..."

            Start-Sleep $RetryInterval
        }
    }

    throw "Programmer error, this code should not execute"
}

function P4_ParseSpecification
{
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [System.Collections.ArrayList] $Content
    )

    $result = [PSCustomObject]@{}

    $inSectionName = $null
    $sectionValue = $null

    for ($i=0; $i -lt $Content.Count; $i++)
    {
        $line = $Content[$i]
        $lineNum = $i + 1

        if ($line -eq $null)
        {
            $message = "Unexpected null found at line $lineNum/$($Content.Count)"
            throw [P4_Parse_Exception]::new($message)
        }

        # Skip comment lines
        if ($line -match '^#')
        {
            continue
        }

        # Blank lines signify the end of a section
        if ($line -eq "")
        {
            if ($inSectionName)
            {
                # Save the multiline $sectionValue (possibly $null if there was no multiline data)
                $result | Add-Member -Name $inSectionName -Type NoteProperty -Value $sectionValue
            }

            $inSectionName = $null
            $sectionValue = $null
            continue
        }

        # If we're not in a section, we expect to open one
        if ($inSectionName -eq $null)
        {
            # Here we allow for whitespace at the beginning, but I'm not sure there will ever be any
            if ($line -match '^\s*([^:]+):\s*(.*)')
            {
                $inSectionName = $matches[1]
                $sectionValue = $matches[2]  # either $null or a non-empty string

                # If we got an inline section value, save it now
                if ($sectionValue)
                {
                    $result | Add-Member -Name $inSectionName -Value $sectionValue -Type NoteProperty

                    # That's it, don't need to worry about any continuations for this section
                    $inSectionName = $null
                    $sectionValue = $null
                }

                continue
            }

            # Malformed input here
            $message = "Unexpected data at line ${lineNum}/$($Content.Count), expected Section start near: $line"
            Write-Warning $message
            throw [P4_Parse_Exception]::new($message)
        }

        # We're currently in a section, processing continuation lines.
        # Each line must start with whitespace, and we trim it from the value.
        if ($line -match '^\s+(.+)')
        {
            $thisLineValue = $matches[1]

            if (-not ($sectionValue))
            {
                # We're adding the first line to this multiline value.
                # Start with an empty array.
                $sectionValue = New-Object System.Collections.ArrayList
            }

            [void] $sectionValue.Add($thisLineValue)
            continue
        }

        # If we're here then something unexpected has happened
        $message = "Parse error at line ${lineNum}/$($Content.Count) near: $line"
        Write-Warning $message
        throw [P4_Parse_Exception]::new($message)
    }

    # We've read the last line; if we're in a section we need to finish processing it
    if ($inSectionName)
    {
        # Save the multiline $sectionValue (possibly $null if there was no multiline data)
        $result | Add-Member -Name $inSectionName -Value $sectionValue -Type NoteProperty
    }

    return $result
}

function P4_GetChange
{
    param(
        [Parameter(Position=0)]
        [string] $CL = $null  # $null same as "default"
    )

    $args = New-Object System.Collections.ArrayList
    [void] $args.Add('change')
    [void] $args.Add('-o')

    if ($CL -ne $null -and $CL -ne "default")
    {
        [void] $args.Add($CL)
    }

    $command = "p4 $($args -join ' ')"
    Write-Debug "EXEC: $command"

    $output = p4 @args

    if ($LASTEXITCODE -ne 0)
    {
        throw [P4_Exception]::new($command, $LASTEXITCODE)
    }

    # Split on lines regardless of which platform created the specification,
    # even if it was different from the current platform
    $lines = $output -split "(?:`r?`n|`r)"

    # Note this may throw; let it propagate if it does
    $result = P4_ParseSpecification -Content $lines

    # Every change specification *MUST* report at the very least the 'Change'
    # property, which is either 'new' or the CL number
    if ($result.Change -eq $null)
    {
        throw [P4_Parse_Exception]::new("Command did not return a valid change specification: $command")
    }

    return $result
}

Export-ModuleMember -Function P4_DecodePath, P4_EncodePath, P4_ParseFileType, P4_ParseChangeLine
Export-ModuleMember -Function P4_FilterIgnoredPaths, P4_GetPendingChangeLists, P4_FStat
Export-ModuleMember -Function P4_ParseSpecification, P4_GetChange
