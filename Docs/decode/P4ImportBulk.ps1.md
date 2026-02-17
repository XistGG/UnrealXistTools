# Decode Analysis: P4ImportBulk.ps1

## Definition
**Path**: `P4ImportBulk.ps1`

### Parameters
- `[switch]$CreateList`: Generate the sync file (`p4 add -n`).
- `[switch]$ImportList`: Import files from the sync file.
- `[switch]$NoParallel`: Disable parallel execution.
- `[switch]$DryRun`: Test run without executing P4 commands.
- `[switch]$DebugPrompts`: Prompt user before each batch execution.
- `[switch]$Help`: Show usage help.
- `[Parameter()]$BatchSize`: Max lines to submit per changelist (default: 50000).
- `[Parameter()]$BucketSize`: Max files per `p4 add` command (default: 50).
- `[Parameter()]$SyncFile`: The file to use for synchronization list (default: `.p4sync.txt`).
- `[Parameter()]$StartLine`: Line number to start processing from (resume capability).
- `[Parameter()]$StopLine`: Line number to stop processing at.
- `[Parameter()]$MaxLines`: Maximum number of lines to process.

## Usages
No usages found in the workspace (other than documentation/README).

## Invocation Details
This script is a standalone tool designed for handling massive P4 imports that might otherwise crash the client.

## Observations
- Checks `[PSVersionCheck.ps1](../../PSVersionCheck.ps1)`.
- Imports `[Modules/P4.psm1](../../Modules/P4.psm1)`.
- Includes sophisticated error recovery logic using the default changelist state.
