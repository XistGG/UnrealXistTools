# Decode Analysis: UProjectSln.ps1

## Definition
**Path**: `UProjectSln.ps1`

### Parameters
- `[Parameter()]$Path`: (Optional) The path to resolve to a `.sln` file.

## Usages
| File | Invocations |
|---|---|
| [Rider.ps1](../../Rider.ps1) | 1 |
| [VS.ps1](../../VS.ps1) | 1 |

## Invocation Details

### [Rider.ps1](../../Rider.ps1)
Lines 35-36:
```powershell
    # Require a valid $UProjectSln
    $UProjectSln =& $PSScriptRoot/UProjectSln.ps1 -Path:$Path
```

### [VS.ps1](../../VS.ps1)
Lines 58-59:
```powershell
Write-Debug "Compute UProjectSln Path=[$Path]"
$UProjectSln =& $PSScriptRoot/UProjectSln.ps1 -Path:$Path
```

## Observations
- Helper script to locate the solution file for a project directory.
