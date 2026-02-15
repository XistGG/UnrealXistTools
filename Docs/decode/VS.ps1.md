# Decode Analysis: VS.ps1

## Definition
**Path**: `VS.ps1`

### Parameters
- `[Switch]$Diff`: Run in Diff mode.
- `[Switch]$Test`: Test mode (no exec).
- `[Parameter(ValueFromRemainingArguments)]$Args`: Arguments (files to diff or project to open).

## Usages
No usages found in the workspace (other than documentation/README).

## Invocation Details
Standalone tool to launch Visual Studio.

## Observations
- Uses `[UProjectSln.ps1](../../UProjectSln.ps1)` to find the solution file.
- Uses `[P4Config.ps1](../../P4Config.ps1)` to setup P4 environment.
