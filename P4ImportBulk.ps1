#
# P4ImportBulk.ps1
#
#    Import Bulk (a LOT of files) into P4.
#
#    When working with a truly massive number of files, P4 will crash
#    and cause you a lot of time trying to figure out where it crashed
#    and how to successfully complete the import.  I'm guessing it runs
#    out of memory?
#
#    The purpose of this script is to break the submit up into chunks,
#    and submit each chunk individually to avoid crashing the p4 client.
#
#    For Usage, see:
#
#        P4ImportBulk.ps1 -Help
#

[CmdletBinding()]
param(
    [switch]$CreateList,
    [switch]$ImportList,
    [switch]$DryRun,
    [switch]$Help,
    [Parameter()]$BatchSize=10000,
    [Parameter()]$BucketSize=50,
    [Parameter()]$SyncFile=".p4sync.txt",
    [Parameter()]$StartLine=1,
    [Parameter()]$StopLine=-1,
    [Parameter()]$MaxLines=-1
)


$ScriptName = $MyInvocation.MyCommand.Name

$SyncFileItem = Get-Item -Path $SyncFile 2> $null
$ValidUsage = $false


function GetHelpOutput()
{
    $FullPathDisplay = $SyncFileItem ? "`"$($SyncFileItem.FullName)`"" : "NO_SUCH_FILE"
    return @"

############################################################
##
##  Usage for ${ScriptName}:
##

Current SyncFile = "$SyncFile"
Full Path = $FullPathDisplay

& $ScriptName -CreateList

    Create $SyncFile like: "p4 add -f -n ... > $SyncFile"

& $ScriptName -ImportList

    Read previously-created $SyncFile and execute multiple
    "p4 submit" with reasonably-sized buckets that won't crash p4.

    Optional additional flags:

      -BatchSize = Max paths to submit to "p4 submit" at once
      -DryRun = Don't actually do anything, just a test run

"@
}

if ($Help)
{
    return &GetHelpOutput
}


################################################################################
##  Create p4sync.txt
################################################################################

if ($CreateList)
{
    $args = @("add", "-f", "-n", "...")

    Write-Host "EXEC: p4 $($args -join ' ') > $SyncFile"
    $process = Start-Process -NoNewWindow -PassThru -FilePath "p4" -ArgumentList $args -RedirectStandardOutput $SyncFile

    if (!$process)
    {
        throw "Failed to start p4 add"
    }

    # Wait for the process we started to exit
    # (NOTE: If it spawns child processes, we do NOT wait for those)
    Wait-Process -InputObject $process
    $e = $process.ExitCode

    if ($e -ne 0)
    {
        throw "p4 add failed"
    }

    $ValidUsage = $true
}


################################################################################
##  Import p4sync.txt
################################################################################

function AddPaths()
{
    [CmdletBinding()]
    param(
        [System.Collections.ArrayList] $Paths
    )

    $args = New-Object System.Collections.ArrayList
    $args.Add("add")
    $args.Add("-f")
    # Add each file path as a quoted argument
    foreach ($Path in $Paths)
    {
        $Escaped = $Path -replace '"','`"'
        $args.Add("`"$Escaped`"")
    }

    if ($DryRun)
    {
        Write-Debug "Skipping add exec due to -DryRun switch"
        Write-Host "NOEXEC: p4 $($args -join ' ')"
        return $null
    }

    Write-Host "EXEC: p4 $($args -join ' ')"
    $process = Start-Process -NoNewWindow -PassThru -FilePath "p4" -ArgumentList $args

    if (!$process)
    {
        throw "Failed to start p4 add"
    }

    # Wait for the process we started to exit
    # (NOTE: If it spawns child processes, we do NOT wait for those)
    Wait-Process -InputObject $process
    $e = $process.ExitCode

    if ($e -ne 0)
    {
        throw "p4 add failed"
    }

    return $process
}


function SubmitPaths()
{
    [CmdletBinding()]
    param(
        [string] $Description
    )

    # Escape quotes in $Description for argument safety
    $args = @("submit", "-d", "`"Bulk Import $($Description -replace '"','`"')`"")

    if ($DryRun)
    {
        Write-Debug "Skipping submit exec due to -DryRun switch"
        Write-Host "NOEXEC: p4 $($args -join ' ')"
        return $null
    }

    Write-Host "EXEC: p4 $($args -join ' ')"
    $process = Start-Process -NoNewWindow -PassThru -FilePath "p4" -ArgumentList $args

    if (!$process)
    {
        throw "Failed to start p4 submit"
    }

    # Wait for the process we started to exit
    # (NOTE: If it spawns child processes, we do NOT wait for those)
    Wait-Process -InputObject $process
    $e = $process.ExitCode

    if ($e -ne 0)
    {
        throw "p4 submit failed"
    }

    return $process
}


if ($ImportList)
{
    if (!$SyncFileItem -or !$SyncFileItem.Exists)
    {
        throw "No [$SyncFile] exists; create it with -CreateList"
    }

    Write-Debug "Reading SyncFile=`"$($SyncFileItem.FullName)`""

    # It's meaningless to start at line less than 1
    if ($StartLine -lt 1)
    {
        $StartLine = 1
    }

    $LineNum = 0
    $TotalOutputLineNum = 0

    $CurrentBatchSize = 0
    $CurrentBucketSize = 0
    $CurrentBucket = New-Object System.Collections.ArrayList

    $SubmitStartLine = $StartLine

    # System.IO.StreamReader REQUIRES AN ABSOLUTE PATH TO THE FILE
    $file = New-Object System.IO.StreamReader($SyncFileItem.FullName)

    if (!$file)
    {
        throw "Cannot open file: $($SyncFileItem.FullName)"
    }

    while (($line = $file.readline()) -ne $null)
    {
        $LineNum++

        # Don't process this line if we're not yet supposed to start
        if ($LineNum -lt $StartLine)
        {
            continue
        }

        Write-Debug "${LineNum}:$line"

        # If the output says the file should be added, then lets add it
        if ($line -imatch '#\d+ - opened for add$')
        {
            $Path = $line -ireplace '#\d+ - opened for add$',''

            # `p4 add -m` writes filenames in an Encoded format, so we need to decode it
            # see: https://www.perforce.com/manuals/cmdref/Content/CmdRef/filespecs.html
            $DecodedPath =& $PSScriptRoot/P4EncodePath.ps1 -Decode -Path $Path

            [void] $CurrentBucket.Add($DecodedPath)

            $TotalOutputLineNum++
            $CurrentBucketSize++
        }

        # Stop if we've reached the max line to process
        if ($StopLine -ge 1 -and $LineNum -ge $StopLine)
        {
            break
        }

        # Stop when we've output enough lines
        if ($MaxLines -gt 0 -and $TotalOutputLineNum -ge $MaxLines)
        {
            break
        }

        # If the bucket is full, add files
        if ($BucketSize -gt 0 -and $CurrentBucketSize -ge $BucketSize)
        {
            # Add these paths and submit to the depot
            $process =& AddPaths -Paths $CurrentBucket

            # Update Batch
            $CurrentBatchSize += $CurrentBucketSize

            # Reset Bucket
            $CurrentBucketSize = 0
            $CurrentBucket = New-Object System.Collections.ArrayList
        }

        # Each time the buckets add up to a batch, submit to the server
        if ($CurrentBatchSize -ge $BatchSize)
        {
            $process =& SubmitPaths -Description "${SubmitStartLine}..${LineNum}"

            # Reset Batch
            $SubmitStartLine = $LineNum + 1
            $CurrentBatchSize = 0
        }
    }

    [void] $file.Dispose()

    # Consume any remaining bucket contents
    if ($CurrentBucketSize -gt 0)
    {
        $process =& AddPaths -Paths $CurrentBucket
        # Update Batch
        $CurrentBatchSize += $CurrentBucketSize
    }

    # Submit any remaining batch contents
    if ($CurrentBatchSize -gt 0)
    {
        $process =& SubmitPaths -Description "${SubmitStartLine}..${LineNum}"
    }

    $ValidUsage = $true
}


################################################################################
##  If not $ValidUsage, show Help
################################################################################

if (!$ValidUsage)
{
    GetHelpOutput | Write-Warning
}
