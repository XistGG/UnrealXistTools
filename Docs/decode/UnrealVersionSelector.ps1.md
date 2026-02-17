# Decode Analysis: UnrealVersionSelector.ps1

## Definition
**Path**: `UnrealVersionSelector.ps1`

### Parameters
- `[switch]$Help`: Show help.
- `[switch]$Editor`: Launch Editor.
- `[switch]$Game`: Launch Game.
- `[switch]$ProjectFiles`: Generate Project Files.
- `[switch]$SwitchVersion`: Switch Engine Version.
- `[switch]$SwitchVersionSilent`: Switch Version silently.
- `[switch]$Force`: Force (remove ReadOnly attribute if needed).
- `[Parameter()] $UProjectFile`: The project file.
- `[Parameter()] $VarArgs`: Remaining arguments.

## Usages
| File | Invocations |
|---|---|
| [UEdit.ps1](../../UEdit.ps1) | 1 |
| [UProjectClean.ps1](../../UProjectClean.ps1) | 1 |

## Invocation Details

### [UEdit.ps1](../../UEdit.ps1)
Lines 60:
```powershell
# Start UVS -Editor on the selected UProjectFile
& $PSScriptRoot/UnrealVersionSelector.ps1 -Editor $UProjectFile.FullName
```

### [UProjectClean.ps1](../../UProjectClean.ps1)
Lines 190:
```powershell
# UnrealVersionSelector.ps1 only works on Windows, so we'll use it.
. $PSScriptRoot\UnrealVersionSelector.ps1 -ProjectFiles $UProjectFile.FullName
```
(Note: It is dot-sourced here to share the process/exit code behavior).

## Observations
- Locates `UnrealVersionSelector.exe` via Windows Registry or Environment.
- Handles read-only project files gracefully if `-Force` is used.
- Crucial for Windows-based project file generation and engine switching.
