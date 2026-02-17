# Decode: INI.psm1

**File**: `Modules/INI.psm1`

## Definition

This module provides helper functions for reading and writing specific sections of INI files. It is primarily used to cross-platform compatibility, specifically for managing Unreal Engine installations on Linux and Mac where the Registry is not available.

### Exported Functions

| Function Name | Parameters | Description |
| :--- | :--- | :--- |
| `INI_ReadSection` | `[string]$Filename`, `[string]$Section`, `[switch]$MayNotExist` | Reads Key=Value pairs from a specific section of an INI file. Returns an ArrayList of PSCustomObjects `{Name, Value}`. |
| `INI_WriteSection` | `[string]$Filename`, `[string]$Section`, `[PSCustomObject]$Pairs` | Writes Key=Value pairs to a specific section of an INI file, preserving other sections. |

## Usages

This module is used by:

| File | Context |
| :--- | :--- |
| `[Modules/UE.psm1](../../Modules/UE.psm1)` | Used to manage custom engine installations on Linux and Mac. |

## Invocation Details

### [Modules/UE.psm1](../../Modules/UE.psm1)

The `UE.psm1` module uses `INI.psm1` to mimic the Windows Registry "Unreal Engine/Builds" key on Linux and Mac, storing the mapping of Engine Names to Root paths in an INI file.

#### Reading Installations

```powershell
function UE_ListCustomEngines_LinuxMac
{
    # ...
    $iniFile = $IsLinux ? $LinuxInstallIni : $MacInstallIni

    $installationPairs =& INI_ReadSection -Filename $iniFile -Section "Installations" -MayNotExist
    # ...
}
```

#### Writing Installations (Renaming)

```powershell
function UE_RenameCustomEngine
{
    # ...
    if ($IsLinux -or $IsMacOS)
    {
        $iniFile = $IsLinux ? $LinuxInstallIni : $MacInstallIni

        # Read the current INI to get the current [Installations] Name=Value pairs
        $installationPairs =& INI_ReadSection -Filename $iniFile -Section "Installations" -MayNotExist

        if ($installationPairs)
        {
            # ... (modify pairs) ...

            # Rewrite the INI with the new [Installations] Name=Value pairs
            $success =& INI_WriteSection -Filename $iniFile -Section "Installations" -Pairs $installationPairs
        }
    }
    # ...
}
```

## Observations
- This module is effectively a lightweight cross-platform alternative to `Get-ItemProperty` / `Set-ItemProperty` for rudimentary configuration storage when the Windows Registry is unavailable.
- It parses INI files manually using Regex, which is sufficient for simple Key=Value pairs.
