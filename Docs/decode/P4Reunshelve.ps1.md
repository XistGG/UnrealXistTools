# Decode Analysis: P4Reunshelve.ps1

## Definition
**Path**: `P4Reunshelve.ps1`

### Parameters
- `[switch]$Force`: Auto-revert changes.
- `[string]$SCL`: (Position 0) Changelist to unshelve.

## Usages
No usages found in the workspace (other than documentation/README).

## Invocation Details
Standalone tool to revert workspace and unshelve a specific CL.

## Observations
- Checks `[PSVersionCheck.ps1](../../PSVersionCheck.ps1)`.
- Imports `[Modules/P4.psm1](../../Modules/P4.psm1)`.
