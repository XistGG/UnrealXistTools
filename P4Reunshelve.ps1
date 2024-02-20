#!/usr/bin/env pwsh
#
# P4Reunshelve.ps1
#
#   "Reunshelve" will repeatedly unshelve files into the current workspace.
#   This script will revert *ALL* changes in your current workspace (it will
#   prompt you for every file unless you -Force) and will then unshelve the
#   -SCL changelist into the current workspace.
#
#   I use this for example when I am testing on multiple workstations
#   simultaneously.  On my primary workstation I make changes, when I'm ready
#   to test, I shelve the changes, then on the other workstation I run this
#   script.  The other workstation never has modifications other than the
#   unshelved changes, I just repeatedly "re-unshelve", discarding whatever
#   the previous shelved files were and replacing them with the new variant.
#

[CmdletBinding()]
param(
    [switch]$Force,
    [string]$SCL
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

# Import the P4 helper module
Import-Module -Name $PSScriptRoot/Modules/P4.psm1

$ScriptName = $MyInvocation.MyCommand.Name

function Usage
{
    $err = "`n" +
    "Usage: $ScriptName [-Debug] [-Force] -SCL 123`n" +
    "`n" +
    "`t[-Debug] If present, prints additional debugging information.`n" +
    "`t[-Force] If present, every change will be automatically reverted`n" +
    "`t-SCL     Required, it is the changelist number to unshelve.`n" +
    ""
    # Write Usage to stderr
    [Console]::Error.WriteLine($err)
    exit 1
}

if (!$SCL -or $SCL -eq "")
{
    & Usage
}

################################################################################
##  Check to see if there are any pending changes in any changelist
################################################################################

Write-Host "Checking P4 workspace for pending changes..."

$command = "p4 opened"
Write-Debug "EXEC: $command"

$output = p4 opened 2> $null
$code = $LASTEXITCODE

if ($code -ne 0)
{
    Write-Error "Error checking for pending p4 changes; Command executed: $command"
    throw "Unexpected exit code: $code"
}

$lines = $output -split "`n"  # Note: $lines may have trailing `r characters
$RevertList = @()

foreach ($line in $lines)
{
    $Result =& P4_ParseChangeLine $line

    if (-not $Result.IsChange)
    {
        Write-Warning "Unexpected output line: $line"
        continue
    }

    #----------------------------------------------------------------------
    # If there is no -Force flag, make the user confirm each and every
    # change before we revert it.
    #----------------------------------------------------------------------

    Write-Debug "Pending Change: $Result"

    if (-not $Force)
    {
        $response = Read-Host "Revert file $($Result.P4Path)? (y|N) [N] "
        $confirmed = $response -ieq 'y'

        if (-not $confirmed)
        {
            # User does not want to revert this file. Abort execution.
            # User will need to clean up their p4 workspace and try again.

            Write-Error "Pending changes detected, user chose not to revert them. Use the -Force flag to auto-revert all changes, or manually shelve or revert changes to continue."
            throw "Operation cancelled by user"
        }
    }

    # Store the encoded, escaped version of the path in the $RevertList
    $EncodedPath =& P4_EncodePath $Result.P4Path
    $RevertList += $EncodedPath
}

################################################################################
##  Revert all pending changes in all changelists
################################################################################

if ($RevertList.Count -gt 0)
{
    Write-Host "Reverting all pending P4 changes..."

    $command = "p4 revert -w $($RevertList -join " ")"
    Write-Debug "EXEC: $command"

    p4 revert -w $RevertList
    $code = $LASTEXITCODE

    if ($code -ne 0)
    {
        Write-Error "Error reverting p4 changes; Command executed: $command"
        throw "Unexpected exit code: $code"
    }
}

################################################################################
##  Unshelve the changes from the shelved changelist into the default changelist
################################################################################

Write-Host "Unshelving files from P4 CL# $SCL..."

$command = "p4 unshelve -s $SCL -c default -Af"
Write-Debug "EXEC: $command"

p4 unshelve -s $SCL -c default -Af
$code = $LASTEXITCODE

if ($code -ne 0)
{
    Write-Error "Error unshelving P4 files; Command executed: $command"
    throw "Unexpected exit code: $code"
}
