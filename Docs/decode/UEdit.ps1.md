# Decode Analysis: UEdit.ps1

## Definition
**Path**: `UEdit.ps1`

### Parameters
- `[Parameter()]$Path`: (Optional) The `.uproject` file to edit.

## Usages
No usages found in the workspace (other than documentation/README).

## Invocation Details
Standalone tool to launch Unreal Editor for a project.

## Observations
- Resolves engine association using `[Modules/UE.psm1](../../Modules/UE.psm1)`.
- Fallbacks to `[UnrealVersionSelector.ps1](../../UnrealVersionSelector.ps1)` if engine not found.
