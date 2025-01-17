#!/usr/bin/env pwsh
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
#    NOTE YOU MUST SORT THE .p4sync.txt TO SUPPORT ERROR RECOVERY.
#    If you use -CreateList to generate the .p4sync.txt it will sort for you.
#
#    Note that before you run -ImportList the first time, you want to
#    MAKE SURE that the default changelist is empty.  Once this starts
#    running, it will be using the default changelist to work.
#
#    Communicating with a p4 server over the public Internet is HIGHLY
#    likely to encounter network errors while running this script, which
#    issues MANY commands to the p4 server while processing.
#
#    This script includes an error recovery mode.  When you start it in
#    -ImportList mode, if the default changelist contains files, it will
#    ask if you want to continue with error recovery.  If you choose yes,
#    then the contents of the default changelist are considered to be
#    the previous work-in-progress that was aborted due to a network error,
#    and processing will continue from that point.
#

[CmdletBinding()]
param(
    [switch]$CreateList,
    [switch]$ImportList,
    [switch]$NoParallel,
    [switch]$DryRun,
    [switch]$DebugPrompts,
    [switch]$Help,
    [Parameter()]$BatchSize=50000,
    [Parameter()]$BucketSize=50,
    [Parameter()]$SyncFile=".p4sync.txt",
    [Parameter()]$StartLine=1,
    [Parameter()]$StopLine=-1,
    [Parameter()]$MaxLines=-1
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

# Import the P4 helper module
Import-Module -Name $PSScriptRoot/Modules/P4.psm1

$ScriptName = $MyInvocation.MyCommand.Name

# Get-Item -Force is required on Mac+Linux for dotfiles
$SyncFileItem = Get-Item -Force -Path $SyncFile 2> $null
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

# FIRST: CREATE THE IMPORT LIST:
& $ScriptName -CreateList

    Create $SyncFile like: "p4 add -f -n ... > $SyncFile"

# THEN: IMPORT THE IMPORT LIST YOU CREATED:
& $ScriptName -ImportList

    Read previously-created $SyncFile and execute multiple
    "p4 submit" with reasonably-sized buckets that won't crash p4.

    If (WHEN) you get network errors that cause the script to stop, just restart
    it and it should resume where it left off after it asks you a few questions.

    Optional additional flags:

      -BatchSize       = Max paths to submit to "p4 submit" at once.
                         50k works for me.  Too high, p4 will crash during
                         the update.  Too low, you get tons of import CLs.
      -BucketSize      = Max number of files to include in one command line
                         (at some point your OS complains max command line
                         length exceeded; not much value in bumping this up)
      -DebugPrompts    = If you set this switch, you will be prompted before each
                         `p4 add` or `p4 submit` command, which means you will be
                         prompted A LOT. Useful for debugging.
      -DryRun          = Don't actually do anything, just a test run
      -NoParallel      = Disable parallel processing in "p4 submit" (SLOW)
                         (Do not use this option unless your P4 server requires it)

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

    Write-Host "Generating ${SyncFile}, this might take a while..."

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

    # Now, to support recovery attempts, SORT the .p4sync.txt
    # so it's in a predictable order and we can restart reliably
    # without losing any files due to random sort order

    Write-Host "Sorting ${SyncFile} to support potential recovery efforts..."

    # -Force is required for dotfiles
    $data = Get-Content -Force -Path $SyncFile
    # Split lines and then sort them
    $lines = $data -split '(?:`r?`n|`r)' | Sort-Object
    # Resave $SyncFile with sorted files
    $lines -join [Environment]::NewLine | Set-Content -Path $SyncFile

    Write-Host "Done."
    Write-Host ""
    Write-Host "If you are going to explicitly add your .p4ignore before you import (highly recommended)," `
               "consider removing .p4ignore from $SyncFile for nicer looking line numbers."
    Write-Host ""
    Write-Host "Ready to -ImportList"

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

    # Add encoded file paths
    foreach ($Path in $Paths)
    {
        [void] $args.Add("`"${Path}`"")  # must double-quote for Start-Process, also must NOT P4_Encode this path
    }

    if ($DryRun)
    {
        Write-Debug "Skipping add exec due to -DryRun switch"
        Write-Host "NOEXEC: p4 $($args -join ' ')"
        return $null
    }

    Write-Host "EXEC: p4 $($args -join ' ')"

    if ($DebugPrompts)
    {
        $userResponse = Read-Host -Prompt "Continue add? [yN] "
        if ($userResponse -ne "y")
        {
            Write-Host "Cancelling prior to add based on user response."
            exit 1
        }
    }

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

    # Escape quotes in $Description (it seems Start-Process just concatenates them?)
    $args = @("submit", "-d", "`"Bulk Import ${Description}`"")

    # If Parallel processing is not explicitly disabled, then enable it,
    # which makes "p4 submit" execute much faster
    if (!$NoParallel)
    {
        $args += "--parallel=threads=8,batch=32"
    }

    if ($DryRun)
    {
        Write-Debug "Skipping submit exec due to -DryRun switch"
        Write-Host "NOEXEC: p4 $($args -join ' ')"
        return $null
    }

    Write-Host "EXEC: p4 $($args -join ' ')"

    if ($DebugPrompts)
    {
        $userResponse = Read-Host -Prompt "Continue submit? [yN] "
        if ($userResponse -ne "y")
        {
            Write-Host "Cancelling prior to submit based on user response."
            exit 1
        }
    }

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


function ImportInBatches
{
    begin
    {
        # It's meaningless to start at line less than 1
        if ($StartLine -lt 1)
        {
            $StartLine = 1
        }

        $StartAfterFile = $null
        $foundStartAfterLine = $false

        $LineNum = 0
        $TotalOutputLineNum = 0

        $CurrentBatchSize = 0
        $CurrentBucketSize = 0
        $CurrentBucket = New-Object System.Collections.ArrayList

        $SubmitStartLine = $StartLine

        # System.IO.StreamReader REQUIRES AN ABSOLUTE PATH TO THE FILE
        $file = New-Object System.IO.StreamReader($SyncFileItem.FullName)

    }
    process
    {
        if (!$file)
        {
            throw "Cannot read file: $($SyncFileItem.FullName)"
        }

        ################################################################################
        ##  Detect error recovery mode
        ################################################################################

        # Start by checking the value of the current default change, since we're using
        # the default change for our work here.
        $initialChange = P4_GetChange
        if ($initialChange.Files -ne $null)
        {
            if (-not ($initialChange.Files -is [System.Collections.ArrayList]))
            {
                # Convert the string into an array
                $initialChange.Files = @( $initialChange.Files )
            }

            # Sort the files so we can predictably recover
            $initialChange.Files = $initialChange.Files | Sort-Object

            # There are one or more files currently in the default changelist
            $numChangeFiles = $initialChange.Files.Count
            $lastAddedFileLine = $initialChange.Files[$numChangeFiles-1]

            $lastChangeFileName = $null
            if ($lastAddedFileLine -match '^([^#]+)#')
            {
                # Trim trailing spaces from the output to get the actual filename
                $lastChangeFileName = $matches[1].TrimEnd()
                # Note that this filename is still encoded!
            }

            if ($lastChangeFileName -eq $null)
            {
                Write-Error "The default changelist contains Files data that cannot be parsed"
                throw "Programmer error - cannot parse last line: `"$lastAddedFileLine`""
            }

            Write-Host ""
            Write-Warning "The default changelist currently contains $numChangeFiles files."
            Write-Host ""
            Write-Host "If you are intentionally recovering from a network error, please continue."
            Write-Host "If you running -ImportList for the first time then STOP NOW AND CLEAN UP THE DEFAULT CHANGELIST BEFORE YOU CONTINUE."
            Write-Host ""

            $userResponse = Read-Host -Prompt "Continue with $numChangeFiles default changelist files? [yN] "
            if ($userResponse -ne "y")
            {
                Write-Host "Cancelling -ImportList. The default changelist is unmodified."
                exit 1
            }

            # By default, start after the last file that was successfully added to the default changelist
            $StartAfterFile = $lastChangeFileName

            Write-Debug "Selected StartAfterFile `"$StartAfterFile`""

            # Initialize the current batch size with the existing default changelist,
            # so we still keep the same max batch size regardless of how many we started with.
            $CurrentBatchSize = $numChangeFiles
        }

        ################################################################################
        ## Process lines from the file
        ################################################################################

        # If we're seeking deep into the file, it might take a while,
        # which looks like the program is fucked; show that it's not.
        if ($StartLine -gt 1000)
        {
            Write-Host "Seeking to Line ${StartLine}..."
        }
        elseif ($StartAfterFile)
        {
            Write-Host "Seeking to line following `"$StartAfterFile`"..."
        }

        # DISABLE CTRL+C DURING `p4 submit`
        [Console]::TreatControlCAsInput = $true

        while (($line = $file.readline()) -ne $null)
        {
            # If user pressed CTRL+C during `p4 submit`, bail out now that it has completed
            if ([Console]::KeyAvailable)
            {
                $key = [Console]::ReadKey($true)
                if ($key.key -eq "C" -and $key.modifiers -eq "Control")
                {
                    # Clean up and exit
                    Write-Error "Exiting due to CTRL+C. To resume where you left off: $ScriptName -ImportList -StartLine $SubmitStartLine"
                    # User pressed CTRL+C; don't add anymore files
                    throw "Terminated by CTRL+C"
                }
            }

            $LineNum++

            # Does this line represent a file we need to add?
            $isAddLine = $line -imatch '#\d+ - opened for add$'
            if ($isAddLine)
            {
                # Extract the path from this line
                $Path = $line -ireplace '#\d+ - opened for add$',''

                # `p4 add -m` writes filenames in an Encoded format, so we need to decode it
                # see: https://www.perforce.com/manuals/cmdref/Content/CmdRef/filespecs.html
                $DecodedPath = P4_DecodePath $Path
            }

            # To support recovery (e.g. after network errors)
            # if $StartAfterFile is set, then don't start processing lines until we find it
            if ($StartAfterFile -and -not $foundStartAfterLine)
            {
                # Compare path (encoded name) with $StartAfterFile (encoded name)
                if ($Path -eq $StartAfterFile)
                {
                    Write-Host "Found StartAfterFile=`"${StartAfterFile}`" at line ${LineNum}"

                    $nextLineNum = $LineNum + 1
                    $userResponse = Read-Host -Prompt "Continue reading $($SyncFileItem.Name) on line ${nextLineNum}? [yN] "
                    if ($userResponse -ne "y")
                    {
                        Write-Host "Cancelling -ImportList. The default changelist is unmodified."
                        exit 1
                    }

                    # We've found the file we were searching for.
                    # Start on the line AFTER this one, which is the first line not yet in the changelist.
                    $foundStartAfterLine = $true
                }

                # Do not start yet, we need at least one more line
                $StartLine = $LineNum + 1
            }

            # Don't process this line if we're not yet supposed to start
            if ($LineNum -lt $StartLine)
            {
                continue
            }

            Write-Debug "${LineNum}:$line"

            # If the output says the file should be added, then lets add it
            if ($isAddLine)
            {
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
                $process =& SubmitPaths -Description "$CurrentBatchSize (lines ${SubmitStartLine}..${LineNum})"

                # Reset Batch
                $SubmitStartLine = $LineNum + 1
                $CurrentBatchSize = 0
            }
        }

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
            $process =& SubmitPaths -Description "$CurrentBatchSize (lines ${SubmitStartLine}..${LineNum})"
        }
    }
    end
    {
        # RE-ENABLE CTRL+C AFTER `p4 submit`
        [Console]::TreatControlCAsInput = $false

        [void] $file.Dispose()
    }
}


if ($ImportList)
{
    if (!$SyncFileItem -or !$SyncFileItem.Exists)
    {
        throw "No [$SyncFile] exists; create it with -CreateList"
    }

    Write-Debug "Reading SyncFile=`"$($SyncFileItem.FullName)`""

    ImportInBatches

    $ValidUsage = $true
}


################################################################################
##  If not $ValidUsage, show Help
################################################################################

if (!$ValidUsage)
{
    GetHelpOutput | Write-Warning
}
