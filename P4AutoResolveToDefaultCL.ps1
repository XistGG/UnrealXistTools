#!/usr/bin/env pwsh
#
# P4AutoResolveToDefaultCL.ps1
#
#   Given a CL that contains for example an integrate result, where a lot of files
#   need to be resolved, auto-resolve (no merging) every file that can be auto resolved,
#   and move it to the default CL.
#
#   After running this, the original $CL will contain ONLY files that could not be
#   auto-resolved, and you'll need to resolve those manually.
#
#   This was very useful in upgrading UE 5.4 to UE 5.5, where there were more than 150k
#   files needing to be resolved, but only a small number actually required manual work.
#   After running this, the $CL with the difficult-to-resolve files was small enough to
#   be worked on by humans.
#
#   Procedure:
#   1. Integrate another stream (or do anything requiring tons of resolves).
#   2. Move all pending file changes to a non-default changelist (e.g. CL#123).
#   3. MAKE SURE the default changelist is EMPTY, we will be moving things there.
#      - If you have pending changes you want to save in the default CL, move them
#        to a new CL now.
#   4. Run P4AutoResolveToDefaultCL.ps1 (this script).
#      - All the "easy" stuff that is auto-resolved will be moved to the default CL.
#      - All the "hard" stuff that requires manual inspection will remain in CL#123.
#   5. Manually resolve all the files still in CL#123.
#   6. Combine CL#123 and the default CL into a single integration CL and submit it.
#

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string] $CL
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

# Import the P4 helper module
Import-Module -Name $PSScriptRoot/Modules/P4.psm1

$BatchSize = 50

$IntegrateFiles = New-Object System.Collections.ArrayList
$OtherFiles = New-Object System.Collections.ArrayList


function AddToOtherFiles
{
    param(
        [string] $DepotFile
    )

    $script:OtherFiles.Add($DepotFile) > $null

    if ($script:OtherFiles.Count -ge $script:BatchSize)
    {
        &FlushOtherFiles
    }
}

function FlushOtherFiles
{
    if ($script:OtherFiles.Count -eq 0)
    {
        return
    }

    Write-Debug "EXEC: p4 reopen -c default $($script:OtherFiles -join ' ')"
    p4 reopen -c default @script:OtherFiles

    $script:OtherFiles.Clear()
}

function FlushIntegrateFiles
{
    if ($script:IntegrateFiles.Count -eq 0)
    {
        return
    }

    $fstatResult =& P4_FStat -Paths $script:IntegrateFiles
    $resolvePaths = New-Object System.Collections.ArrayList

    foreach ($fstat in $fstatResult)
    {
        if ($fstat.unresolved -and -not $fstat.resolved)
        {
            # This file is marked as needing to be resolved
            $resolvePaths.Add($fstat.depotFile) > $null
        }
        else
        {
            # This does not require manual processing, it has already been resolved
            # or does not need to be resolved.  Move to the default CL
            &AddToOtherFiles -DepotFile $fstat.depotFile
        }
    }

    # We've preserved any files from $IntegrateFiles that we need to process below,
    # so reset it for new files to be added by outside procs.

    $script:IntegrateFiles.Clear()

    # Any files that were marked as resolve, try to do a safe (non-merge) auto-resolve
    # and if that succeeds, then move this file to the other files list

    if ($resolvePaths.Count -gt 0)
    {
        Write-Debug "EXEC: p4 resolve -c $CL -as $($resolvePaths -join ' ')"
        p4 resolve -c $CL -as @resolvePaths

        # Check the new fstat for these files to see if they were successfully resolved or not
        $fstatResult =& P4_FStat -Paths $resolvePaths

        foreach ($fstat in $fstatResult)
        {
            if ($fstat.resolved) # if it's now successfully resolved
            {
                # This does not require manual processing, move it to the default CL
                &AddToOtherFiles -DepotFile $fstat.depotFile
            }
            # otherwise keep it in the original CL, it will require manual resolving
        }
    }
}

function ProcessChange
{
    param(
        [string] $DepotFile,
        [string] $ChangeType
    )

    $script:IntegrateFiles.Add($DepotFile) > $null

    if ($script:IntegrateFiles.Count -ge $script:BatchSize)
    {
        &FlushIntegrateFiles
    }
}

##########

try
{
    # Create a temp file to use for this operation
    $tempFile = New-TemporaryFile

    # Run p4 describe, which can output many MB of result
    Write-Debug "EXEC: p4 describe -s $CL"
    $proc = Start-Process -NoNewWindow -PassThru -FilePath "p4" -ArgumentList "describe -s $CL" -RedirectStandardOutput $tempFile.FullName
    Wait-Process -InputObject $proc

    # Read the file and process the lines individually
    $tempReader = [System.IO.StreamReader]::new($tempFile.FullName)

    while (($line = $tempReader.ReadLine()) -ne $null)
    {
        #Write-Debug "LINE: $line"

        # Ignore header lines that don't start with "... ",
        # we're only interested in the lines that identify files in this changelist
        if ($line -match "^\.\.\.\s+(//[^#]+)#(\d+)\s+(.+)")
        {
            $depotFile = $matches[1]  # note: this path is p4-encoded
            $revision = $matches[2]
            $changeType = $matches[3]

            &ProcessChange -DepotFile $depotFile -ChangeType $changeType
        }
    }

    &FlushIntegrateFiles
    &FlushOtherFiles
}
finally
{
    # Close stream reader if it's open
    if ($tempReader)
    {
        $tempReader.Dispose()
        $tempReader = $null
    }

    # Clean up the temp file if we created one
    if (Test-Path -Path $tempFile.FullName)
    {
        Remove-Item -Path $tempFile.FullName
    }
}
