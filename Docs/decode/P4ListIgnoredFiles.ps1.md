# Decode Analysis: P4ListIgnoredFiles.ps1

## Definition
**Path**: `P4ListIgnoredFiles.ps1`

### Parameters
- `[string]$Path`: The root path to scan (default: current directory).
- `[int32] $BatchSize`: Batch size for processing files (default: 100).

## Usages
No usages found in the workspace (other than documentation/README).

## Invocation Details
Standalone tool to find ignored files.

## Observations
- Checks `[PSVersionCheck.ps1](../../PSVersionCheck.ps1)`.
- Imports `[Modules/P4.psm1](../../Modules/P4.psm1)`.
