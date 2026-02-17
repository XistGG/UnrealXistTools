# Decode: UProjectFile.ps1

*   **File**: [UProjectFile.ps1](../../UProjectFile.ps1)
*   **Path**: `UProjectFile.ps1`

## Definition

`UProjectFile.ps1` is a utility script that takes an optional path and expands it to an actual `.uproject` file location. If provided a directory, it intelligently searches for the `.uproject` file within it, handling cases with multiple project files by selecting the one matching the directory name, or erroring if ambiguous.

**Parameters**:
*   `$Path` (Position 0, Optional): Path to a file or directory.

**Returns**:
*   A `System.IO.FileInfo` object representing the `.uproject` file.

## Usages

| File | Type | Purpose |
| :--- | :--- | :--- |
| [UProject.ps1](../../UProject.ps1) | `&` Call | Core logic to locate the `.uproject` file before parsing it. |
| [UnrealVersionSelector.ps1](../../UnrealVersionSelector.ps1) | `&` Call | Resolves the project file to update version selector. |
| [Rider.ps1](../../Rider.ps1) | `&` Call | Locates the project to generate solution or open in Rider. |
| [RefactorUProject.ps1](../../RefactorUProject.ps1) | `&` Call | Locates the "From" project file to be refactored. |

## Invocation Details

### [UProject.ps1](../../UProject.ps1)

```powershell
24: $UProjectFile =& $PSScriptRoot/UProjectFile.ps1 -Path:$Path
```

### [UnrealVersionSelector.ps1](../../UnrealVersionSelector.ps1)

```powershell
32: $UProjectFile = & $PSScriptRoot\UProjectFile.ps1 -Path:$UProjectFile
```

### [Rider.ps1](../../Rider.ps1)

```powershell
50: $UProjectFile =& $PSScriptRoot/UProjectFile.ps1 -Path:$Path
```

### [RefactorUProject.ps1](../../RefactorUProject.ps1)

```powershell
64: $FromUProjectFile =& $PSScriptRoot/UProjectFile.ps1 -Path:$From
```

## Observations

*   **Foundation**: This script is the "single source of truth" for how to find a `.uproject` file given a potentially messy input (a directory, a relative path, null, etc.).
*   **Encapsulation**: By isolating the file discovery logic here, other scripts don't need to re-implement directory scanning or ambiguity checks.
*   **Separation of Concerns**: It cleanly separates finding the file (returning `FileInfo`) from parsing the file (done by `UProject.ps1`).
