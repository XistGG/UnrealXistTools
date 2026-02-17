# Decode: UE.psm1

**File**: `Modules/UE.psm1`

## Definition

This module provides helper functions for managing and interacting with Unreal Engine installations, including custom-built engines and launcher-installed engines (where possible). It handles cross-platform differences (Windows/Linux/Mac) for engine registration and path resolution.

### Exported Functions

| Function Name | Parameters | Description |
| :--- | :--- | :--- |
| `UE_GetEngineConfig` | `[string]$BuildConfig`, `[string]$EngineDir`, `[string]$EngineRoot` | Returns a configuration object containing paths to key engine executables (Editor, UAT, UBT, GenerateProjectFiles) and directories. |
| `UE_GetEngineByAssociation` | `[string]$UProjectFile`, `[string]$EngineAssociation` | Resolves the engine root path given a `.uproject` file and its Engine Association (GUID, Name, or relative path). |
| `UE_ListCustomEngines` | `None` | Returns a list of all registered custom engines on the system. |
| `UE_SelectCustomEngine` | `[string]$Name`, `[string]$Root` | Selects a specific custom engine by its Name or Root path. |
| `UE_RenameCustomEngine` | `[string]$OldName`, `[string]$NewName` | Renames a registered custom engine in the Registry (Windows) or INI file (Linux/Mac). |

## Usages

| File | Context |
| :--- | :--- |
| `[UProjectClean.ps1](../../UProjectClean.ps1)` | Used to find the engine root to run `GenerateProjectFiles`. |
| `[UEngine.ps1](../../UEngine.ps1)` | CLI tool for managing custom engines (List, Rename, Select). |
| `[UEdit.ps1](../../UEdit.ps1)` | Used to find the engine editor executable to launch the project. |
| `[UAT.ps1](../../UAT.ps1)` | Used to find the UAT/UBT scripts for building/cooking/packaging. |

## Invocation Details

### [UEdit.ps1](../../UEdit.ps1)

Used to find the correct editor executable to launch a project.

```powershell
    $UEngine =& UE_GetEngineByAssociation -UProjectFile $UProjectFile.FullName -EngineAssociation $UProject.EngineAssociation

    if ($UEngine -and $UEngine.Root)
    {
        $UEngineConfig =& UE_GetEngineConfig -EngineRoot $UEngine.Root

        # Open the UProject in UEditor
        & $UEngineConfig.Binaries.Editor $UProjectFile.FullName
    }
```

### [UAT.ps1](../../UAT.ps1)

Used to find the UAT/UBT scripts for build operations.

```powershell
    $UProjectInfo = & $PSScriptRoot\UProject.ps1 -Path:$Path
    # ...
    $Engine = & UE_GetEngineByAssociation -UProjectFile:$UProjectFile -EngineAssociation:$EngineAssociation
    # ...
    $EngineConfig = & UE_GetEngineConfig -BuildConfig:$Config -EngineDir:$EngineDir

    $UAT = $EngineConfig.UAT
    # or
    $UAT = $EngineConfig.UBT
```

### [UEngine.ps1](../../UEngine.ps1)

Used to list or modify custom engine registrations.

```powershell
    $BuildList =& UE_ListCustomEngines

    # ...

    if ($NewName)
    {
        # Rename the engine
        $UEngine =& UE_RenameCustomEngine -OldName $UEngine.Name -NewName $NewName
    }
```

## Observations
- This module abstracts away the platform-specific details of finding Unreal Engine installations (Registry on Windows, INI on Linux/Mac).
- It standardizes access to critical engine tools like UAT, UBT, and the Editor across different engine versions and platforms.
- It robustly handles both "Source" (custom) builds and "Installed" (Launcher/Binary) builds, although some launcher-specific logic is noted as "Not implemented" for Linux/Mac in `UE_GetEngineByAssociation`.
