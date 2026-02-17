# Decode Analysis: P4ObliterateIgnoredFiles.ps1

## Definition
**Path**: `P4ObliterateIgnoredFiles.ps1`

### Parameters
- `[switch] $y`: Confirm obliteration (otherwise dry-run).
- `[string] $Path`: Root path to scan (default: current directory).

## Usages
No usages found in the workspace (other than documentation/README).

## Invocation Details
Standalone tool to obliterate files from P4 that are locally ignored.

## Observations
- Checks `[PSVersionCheck.ps1](../../PSVersionCheck.ps1)`.
- Imports `[Modules/P4.psm1](../../Modules/P4.psm1)`.
