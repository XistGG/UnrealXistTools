# Decode Analysis: P4EncodePath.ps1

## Definition
**Path**: `P4EncodePath.ps1`

### Parameters
- `[switch]$Decode`: Decode the given path (default is Encode).
- `[switch]$Help`: Show usage help.
- `[switch]$Test`: Run internal tests.
- `[Parameter()]$Path`: The path to process.

## Usages
No usages found in the scripts (other than documentation/README). However, it defines helper functions `P4_EncodePath` and `P4_DecodePath` via `Modules/P4.psm1` (implied logic, actually it imports `[Modules/P4.psm1](../../Modules/P4.psm1)` to verify functionality, but the script itself calls the module functions or acts as a cli wrapper).

## Invocation Details
This script acts as a CLI wrapper around the internal P4 module functions.

## Observations
- Checks `[PSVersionCheck.ps1](../../PSVersionCheck.ps1)`.
- Imports `[Modules/P4.psm1](../../Modules/P4.psm1)`.
