# UnrealXistTools Agents & Tools

This file documents the various tools and scripts available in the `UnrealXistTools` repository, acting as a guide for agents and developers.

## Critical: Reloading Modules

PowerShell aggressively caches loaded modules. If you make changes to a `.psm1` file, **simple re-importing will not work**.

To force a reload of a module in the current session, you must use the `-Force` parameter:

```powershell
Import-Module -Name .\Modules\MyModule.psm1 -Force
```

Alternatively, you can remove it first (though `-Force` usually suffices):

```powershell
Remove-Module MyModule
Import-Module .\Modules\MyModule.psm1
```

If you are running tests using `RunTests.ps1` or Pester directly, ensure that the test script or the runner explicitly re-imports the module module under test using `-Force` to pick up your latest changes.

## Core Modules

Located in `Modules/`, these PowerShell modules provide shared functionality:

-   **`INI.psm1`**: Handling INI file parsing and manipulation.
-   **`P4.psm1`**: Perforce (P4) wrapper functions and utilities.
-   **`UE.psm1`**: Unreal Engine specific utilities (e.g., path handling, registry checks).

## Build Tools

-   **`UAT.ps1`**: Wrapper for `RunUAT`, auto-computing arguments.
-   **`UProjectClean.ps1`**: Cleans project directories (Binaries, Intermediate, etc.) and regenerates project files.
-   **`UEdit.ps1`**: Opens the current project in Unreal Editor.
-   **`UnrealVersionSelector.ps1`**: Interface to `UnrealVersionSelector.exe`.

## IDE Tools

-   **`Rider.ps1`**: Opens the project in Rider, setting up P4 environment.
-   **`VS.ps1`**: Opens the project in Visual Studio, setting up P4 environment.

## Engine Tools

-   **`MigrateUEMarketplacePlugin.ps1`**: Migrates plugins between engine versions.
-   **`UEngine.ps1`**: Manages custom engine builds and registry keys.

## Project Tools

-   **`UProject.ps1`**: Parses and returns `.uproject` content.
-   **`UProjectFile.ps1`**: Locates the `.uproject` file.
-   **`UProjectSln.ps1`**: Locates the `.sln` file.

## Perforce (P4) Tools

-   **`P4AutoResolveToDefaultCL.ps1`**: Auto-resolves merge conflicts to the default changelist.
-   **`P4Config.ps1`**: Locates and imports `.p4config`.
-   **`P4EncodePath.ps1`**: Encodes/decodes P4 paths.
-   **`P4FStat.ps1`**: Object-based `p4 fstat`.
-   **`P4ImportBulk.ps1`**: Bulk import of files into P4.
-   **`P4Info.ps1`**: Parses `p4 info`.
-   **`P4LastGreenBuild.ps1`**: gets the last green build from a specific stream.
-   **`P4ObliterateIgnoredFiles.ps1`**: Obliterates ignored files from P4.
-   **`P4RemergeSidestream.ps1`**: Helper for re-merging side streams.
-   **`P4Reunshelve.ps1`**: Reverts and re-unshelves changes.

## Other Scripts

-   **`GitMakeExecutable.ps1`**: Makes files executable in Git.
-   **`PSVersionCheck.ps1`**: Checks PowerShell version.
