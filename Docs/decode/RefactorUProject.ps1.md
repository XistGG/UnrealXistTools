# Decode Analysis: RefactorUProject.ps1

## Definition
**Path**: `RefactorUProject.ps1`

### Parameters
- `[Parameter(Mandatory)]$From`: Source project `.uproject` file.
- `[Parameter(Mandatory)]$To`: Destination directory.
- `[Parameter(Mandatory)]$OldPackageName`: Original project name.
- `[Parameter(Mandatory)]$NewPackageName`: New project name.
- `[Parameter(Mandatory)]$OldCodePrefix`: Original class prefix (e.g. `Xcgs`).
- `[Parameter(Mandatory)]$NewCodePrefix`: New class prefix (e.g. `Noob`).
- `[Switch]$Force`: Force overwrite.

## Usages
No usages found in the workspace (other than documentation/README).

## Invocation Details
Standalone tool for rigorous project refactoring (renaming).

## Observations
- WARNING: Does not refactor UAssets. User must manually fix binary assets.
- Adds `[CoreRedirects]` to `DefaultEngine.ini`.
- Uses `[UProjectFile.ps1](../../UProjectFile.ps1)` to validate input.
