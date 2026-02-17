# Decode Analysis: Rider.ps1

## Definition
**Path**: `Rider.ps1`

### Parameters
- `[Parameter()]$Path`: Optional path to `.uproject` or `.sln`.
- `[switch]$Sln`: Force SLN mode (open solution instead of project).

## Usages
No usages found in the workspace (other than documentation/README).

## Invocation Details
Standalone tool to open Rider with P4 environment configured.

## Observations
- Uses `[UProjectSln.ps1](../../UProjectSln.ps1)` to resolve solution files.
- Uses `[UProjectFile.ps1](../../UProjectFile.ps1)` to resolve project files.
- Uses `[P4Config.ps1](../../P4Config.ps1)` to export environment variables.
