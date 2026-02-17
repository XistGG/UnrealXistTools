# Decode Analysis: P4RemergeSidestream.ps1

## Definition
**Path**: `P4RemergeSidestream.ps1`

### Parameters
- `[string] $CL`: (Mandatory) Source changelist.
- `[string] $SourceDepot`: (Mandatory) Source depot path (e.g. `//XE/Lyra-Xist`).
- `[string] $SourceDir`: (Mandatory) Local directory of source stream.
- `[string] $LocalDir`: (Optional) Validation logic exists to default to current directory.
- `[HashTable] $TranslationRules`: (Optional) Rules for path translation.
- `[switch] $Force`: Force execution.

## Usages
| File | Invocations |
|---|---|
| [P4RemergeLyraExample.ps1](../../P4RemergeLyraExample.ps1) | 1 |

## Invocation Details

### [P4RemergeLyraExample.ps1](../../P4RemergeLyraExample.ps1)
Lines 40-45:
```powershell
& $PSScriptRoot/P4RemergeSidestream.ps1 `
    -CL:$CL -Force:$Force `
    -SourceDepot "//XE/Lyra-Xist" `
    -SourceDir "D:/Dev/Lyra-Xist" `
    -LocalDir "D:/Dev/XimMain/Xim" `
    -TranslationRules:$TranslationRules
```

## Observations
- Checks `[PSVersionCheck.ps1](../../PSVersionCheck.ps1)`.
- Imports `[Modules/P4.psm1](../../Modules/P4.psm1)`.
