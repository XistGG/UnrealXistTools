# 
# P4StreamClean.ps1
#
# See: https://github.com/XistGG/UnrealXistTools/
#
#   This script will compare all of the files currently in a P4 Stream
#   against the current .p4ignore configuration.  It will then:
#
#   - Show a list of all files that exist in the Depot, but should be ignored.
#   - Allow the should-be-ignored files to easily be removed.
#

[CmdletBinding()]
param(
    [switch]$Clean,
    [switch]$DryRun,
    [switch]$Init,
    [switch]$Scan,
    [Parameter()]$StartLine=1,
    [Parameter()]$StopLine=-1,
    [Parameter()]$MaxLines=-1
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

$ScriptName = $MyInvocation.MyCommand.Name


################################################################################
##  Initialization
################################################################################

# We must have a valid P4 Config.
# Get the config from P4Info.ps1

$P4Info =& $PSScriptRoot/P4Info.ps1 -Full

if (!$P4Info)
{
    Write-Error "To run this script you must have your P4 environment configured."
    throw "Invalid response from P4Info.ps1"
}

$P4ClientStream = $P4Info["Client stream"];
Write-Debug "Using P4 Client stream [$P4ClientStream]"

if (!$P4ClientStream -or $P4ClientStream -eq "")
{
    throw "Cannot get 'Client stream' from P4Info.ps1"
}

$P4ClientRoot = $P4Info["Client root"];
Write-Debug "Using P4 Client root [$P4ClientRoot]"

if (!$P4ClientRoot -or $P4ClientRoot -eq "")
{
    throw "Cannot get 'Client root' from P4Info.ps1"
}

if (!(Test-Path -Path $P4ClientRoot -PathType Container))
{
    throw "P4 'Client root' [$P4ClientRoot] is not a valid directory"
}

# The /.p4sync.txt file in the workspace root.
# If you follow Xist's (or Epic's) .p4ignore guidelines, this will be ignored
# so it's a safe place to store p4 sync info.
# @see https://github.com/XistGG/Perforce-Setup

$P4SyncFile = Join-Path $P4ClientRoot ".p4sync.txt"


################################################################################
###  Help
################################################################################

function GetHelpOutput()
{
    return @"

Usage: $ScriptName

# FIRST: Initialize by generating a list of all files in the stream:
& $ScriptName -Init

# THEN: Perform a -Scan to see the files that would be deleted:
& $ScriptName -Scan > /tmp/files-to-delete

# THEN: When you are happy with the list of files that would be deleted,
# perform an actual -Clean to mark all the files for deletion.
& $ScriptName -Clean

# FINALLY: Run `p4 submit` to commit the deletes to the P4 depot
p4 submit -d "Stream maintenance: P4StreamClean.ps1"

"@
}


################################################################################
###  Functions
################################################################################

function RemoveP4SyncFile()
{
    if (Test-Path -Path $P4SyncFile)
    {
        Write-Debug "Removing P4SyncFile [$P4SyncFile]"
        Remove-Item -Path $P4SyncFile

        if (Test-Path -Path $P4SyncFile)
        {
            throw "Cannot remove temp P4 sync file [$P4SyncFile]"
        }
    }
}

function ShouldFileBeIgnored()
{
    [CmdletBinding()]
    param(
        [string]$Path
    )

    # @see https://www.perforce.com/manuals/cmdref/Content/CmdRef/p4_ignores.html
    # p4 ignores -i "Path"
    $EscapedPath = $Path -replace '"','`"'
    $args = @("ignores", "-i", "`"$EscapedPath`"")

    Write-Debug "EXEC: p4 $($args -join ' ')"
    $output = Invoke-Expression "p4 $($args -join ' ')"

    if ($output -imatch ' ignored$')
    {
        return $true
    }

    return $false
}

function P4Delete()
{
    [CmdletBinding()]
    param(
        [string]$Path
    )

    # @see https://www.perforce.com/manuals/cmdref/Content/CmdRef/p4_delete.html
    # p4 delete -k "Path"
    $EscapedPath = $Path -replace '"','`"'
    $args = @("delete", "-k", "`"$EscapedPath`"")

    Write-Debug "EXEC: p4 $($args -join ' ')"
    $process = Start-Process -NoNewWindow -PassThru -FilePath "p4" -ArgumentList $args

    if (!$process)
    {
        throw "Failed to run p4 delete"
    }

    # Wait for the process we started to exit
    # (NOTE: If it spawns child processes, we do NOT wait for those)
    Wait-Process -InputObject $process
    $e = $process.ExitCode

    if ($e -ne 0)
    {
        throw "p4 delete failed"
    }

    return $process
}

function RetrieveStreamFiles()
{
    # @see https://www.perforce.com/manuals/cmdref/Content/CmdRef/p4_files.html
    # p4 files -e -i "$P4ClientStream/..."
    $args = @("files", "-e", "-i", "`"$P4ClientStream/...`"")

    # Remove P4SyncFile before we run `p4 files`
    & RemoveP4SyncFile

    Write-Host "EXEC: p4 $($args -join ' ')"
    $process = Start-Process -NoNewWindow -PassThru -FilePath "p4" -ArgumentList $args -RedirectStandardOutput $P4SyncFile

    if (!$process)
    {
        throw "Failed to run p4 files"
    }

    # Wait for the process we started to exit
    # (NOTE: If it spawns child processes, we do NOT wait for those)
    Wait-Process -InputObject $process
    $e = $process.ExitCode

    if ($e -ne 0)
    {
        throw "p4 files failed"
    }

    return $process
}

function CleanStreamFiles()
{
    [CmdletBinding()]
    param(
        [switch]$Scan
    )

    $ActivityName = "Cleaning"
    if ($Scan)
    {
        $ActivityName = "Scanning"
    }

    $P4SyncFileItem = Get-Item $P4SyncFile
    if (!$P4SyncFileItem -or !$P4SyncFileItem.Exists)
    {
        Write-Error "You must run ``$ScriptName -Init`` before you can ``-Clean``"
        throw "P4 Sync File [$P4SyncFile] does not exist"
    }

    Write-Debug "Counting number of lines in $P4SyncFile"

    # System.IO.StreamReader REQUIRES AN ABSOLUTE PATH TO THE FILE
    $file = New-Object System.IO.StreamReader($P4SyncFileItem.FullName)
    if (!$file)
    {
        throw "Cannot open P4 Sync File [$P4SyncFile]"
    }
    $TotalNumLines = 0
    while (($line = $file.readline()) -ne $null)
    {
        $TotalNumLines++
    }
    [void] $file.Dispose()

    # System.IO.StreamReader REQUIRES AN ABSOLUTE PATH TO THE FILE
    $file = New-Object System.IO.StreamReader($P4SyncFileItem.FullName)
    if (!$file)
    {
        throw "Cannot open P4 Sync File [$P4SyncFile]"
    }

    Write-Debug "Scanning $P4SyncFile looking for files that should be ignored..."

    $NumDeleted = 0
    $LineNum = 0
    $StartTime = [long] (Get-Date -UFormat %s)

    while (($line = $file.readline()) -ne $null)
    {
        $LineNum++

        if ($StartLine -gt 0 -and $LineNum -lt $StartLine)
        {
            continue
        }

        if ($StopLine -gt 0 -and $LineNum -gt $StopLine)
        {
            break
        }

        if ($MaxLines -gt 0 -and $LineNum - $StartLine -ge $MaxLines)
        {
            break
        }

        if ($LineNum % 50 -eq 0)
        {
            $TimeNow = [long] (Get-Date -UFormat %s)
            $ElapsedTime = $TimeNow - $StartTime
            $TimePerLine = $ElapsedTime / $LineNum
            $ETR = $TimePerLine * ($TotalNumLines - $LineNum)
            $TimeSpan = New-TimeSpan -Seconds $ETR
            $TimeString = '{0:00}:{1:00}:{2:00}' -f $TimeSpan.Hours, $TimeSpan.Minutes, $TimeSpan.Seconds

            $PercentComplete = [Math]::Min(100, $LineNum / $TotalNumLines * 100)
            $WholePercentComplete = [Math]::Floor($PercentComplete)
            Write-Progress -Activity $ActivityName -Status "$LineNum / $TotalNumLines ($WholePercentComplete%) -- $NumDeleted to delete -- ETA: $TimeString" -PercentComplete $PercentComplete
        }

        Write-Debug "${LineNum}:$line"

        if ($line -match "^$P4ClientStream/.*#")
        {
            # Remove leading $P4ClientStream and trailing "# everything"
            # This will isolate the relative file path
            $Path = $line -ireplace "^$P4ClientStream/",'' -ireplace '#.*',''

            # `p4 files` writes filenames in an Encoded format, so we need to decode it
            # see: https://www.perforce.com/manuals/cmdref/Content/CmdRef/filespecs.html
            $DecodedPath =& $PSScriptRoot/P4EncodePath.ps1 -Decode -Path $Path

            if (&ShouldFileBeIgnored -Path:$DecodedPath)
            {
                $NumDeleted++

                if ($Scan)
                {
                    # Write-Output allows output to be redirected to a file in terminal
                    Write-Output $DecodedPath
                }
                elseif ($DryRun)
                {
                    Write-Debug "Would have deleted: $DecodedPath"
                }
                else
                {
                    &P4Delete -Path:$DecodedPath
                }
            }
        }
    }

    Write-Progress -Activity $ActivityName -Completed

    [void] $file.Dispose()

    if ($Scan)
    {
        return;
    }

    if ($DryRun)
    {
        return "DryRun: Would have deleted $NumDeleted files"
    }
    return "Deleted $NumDeleted files"
}


################################################################################
##  Main
################################################################################

if ($Init)
{
    & RetrieveStreamFiles

    if (!$Clean -and !$Scan)
    {
        return "Init complete. Stream file list stored in: $P4SyncFile"
    }
}

if ($Scan)
{
    return & CleanStreamFiles -Scan
}
elseif ($Clean)
{
    return & CleanStreamFiles
}

return & GetHelpOutput
