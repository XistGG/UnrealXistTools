# Decode Analysis: P4FilterIgnored.ps1

## Definition
**Path**: `P4FilterIgnored.ps1`

### Parameters
- `[string[]]$Paths`: (ValueFromRemainingArguments) The list of paths to check against P4 ignore rules.

## Usages
No usages found in the workspace (other than documentation/README).

## Invocation Details
This script acts as a CLI wrapper around the internal `P4_FilterIgnoredPaths` function from the module `[Modules/P4.psm1](../../Modules/P4.psm1)`.

## Observations
- Checks `[PSVersionCheck.ps1](../../PSVersionCheck.ps1)`.
- Imports `[Modules/P4.psm1](../../Modules/P4.psm1)`.
