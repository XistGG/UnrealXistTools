# Decode: UEngine.ps1

*   **File**: [UEngine.ps1](../../UEngine.ps1)
*   **Path**: `UEngine.ps1`

## Definition

`UEngine.ps1` is a standalone PowerShell script designed to allow the user to list, select, and rename Unreal Engine builds registered in the Windows Registry. It acts as a CLI wrapper around functions provided by `Modules/UE.psm1`.

**Parameters**:
*   `$Name` (Optional): Name or GUID of the engine build.
*   `$NewName` (Optional): New name to assign to the specified engine.
*   `$UProject` (Optional): Path to a project to determine the engine from.
*   `[switch]$List`: List all registered engines.
*   `[switch]$NoDefault`: Do not auto-select a default engine.
*   `[string]$Config`: Engine build configuration (e.g. "Development").

## Usages

**No direct script invocations found.**

This script appears to be a top-level user tool, intended to be run directly by the user rather than consumed by other scripts.

It is heavily documented in [README.md](../../README.md) and [AGENTS.md](../../AGENTS.md).

## Observations

*   **Standalone Utility**: Unlike `UProject.ps1` or `UProjectFile.ps1`, this script is not a building block but an interface for engine management.
*   **Module Wrapper**: Its primary logic delegates to `Modules/UE.psm1` (e.g., `UE_ListCustomEngines`, `UE_SelectCustomEngine`, `UE_RenameCustomEngine`).
*   **Project Awareness**: It can discover the engine associated with a project using `UProject.ps1` (Lines 108, 123), showcasing the dependency on the core project resolution logic.
