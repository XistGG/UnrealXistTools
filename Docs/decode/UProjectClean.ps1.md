# Decode Analysis: UProjectClean.ps1

## Definition
**Path**: `UProjectClean.ps1`

### Parameters
- `[switch]$DryRun`: Simulate deletion.
- `[switch]$Idea`: Delete `.idea` folder.
- `[switch]$DDC`: Delete `DerivedDataCache`.
- `[switch]$Nuke`: Deletes everything (Idea, DDC, Saved, Intermediate, Binaries).
- `[switch]$Saved`: Delete `Saved` folder.
- `[switch]$VSCode`: Generate VSCode project files.
- `[Parameter()]$Path`: Project path.

## Usages
No usages found in the workspace (other than documentation/README).

## Invocation Details
Standalone tool to clean intermediate files.

## Observations
- Regenerates project files after cleaning.
- Uses `[UnrealVersionSelector.ps1](../../UnrealVersionSelector.ps1)` on Windows as a fallback for generating project files.
