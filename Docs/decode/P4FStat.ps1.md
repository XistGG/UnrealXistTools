# Decode Analysis: P4FStat.ps1

## Definition
**Path**: `P4FStat.ps1`

### Parameters
- `[object]$Path`: (Mandatory) A string or array of strings representing file paths to inspect.

## Usages
No usages found in the workspace (other than documentation/README).

## Invocation Details
This script acts as a CLI wrapper around the internal `P4_FStat` function from the module `[Modules/P4.psm1](../../Modules/P4.psm1)`.

## Observations
- Checks `[PSVersionCheck.ps1](../../PSVersionCheck.ps1)`.
- Imports `[Modules/P4.psm1](../../Modules/P4.psm1)`.
