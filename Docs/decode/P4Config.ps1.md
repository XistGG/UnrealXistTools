# Decode Analysis: P4Config.ps1

## Definition
**Path**: `P4Config.ps1`

### Parameters
- `[switch]$Export`: If set, exports configuration to environment variables.
- `[Parameter()]$Path`: Optional directory path to search for `.p4config`. Defaults to current location.

## Usages
| File | Invocations |
|---|---|
| [Rider.ps1](../../Rider.ps1) | 1 |
| [VS.ps1](../../VS.ps1) | 1 |
| [PyCharm.ps1](../../PyCharm.ps1) | 1 |

## Invocation Details

### [Rider.ps1](../../Rider.ps1)
Lines 62-63:
```powershell
# Locate a .p4config and export it to the system environment before starting Rider
& $PSScriptRoot/P4Config.ps1 -Export -Path $RiderFile.Directory.FullName
```

### [VS.ps1](../../VS.ps1)
Lines 70-71:
```powershell
# Locate a .p4config and export it to the system environment before starting Rider
& $PSScriptRoot/P4Config.ps1 -Export -Path $UProjectSln.Directory.FullName
```

### [PyCharm.ps1](../../PyCharm.ps1)
Lines 40-41:
```powershell
# Locate a .p4config and export it to the system environment before starting PyCharm
& $PSScriptRoot/P4Config.ps1 -Export -Path $PathItem.FullName
```

## Observations
- Used primarily by IDE launch scripts to configure the Perforce environment before launching the IDE.
- Checks `[PSVersionCheck.ps1](../../PSVersionCheck.ps1)`.
