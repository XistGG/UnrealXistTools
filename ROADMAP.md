# UnrealXistTools Roadmap

This document outlines the future work and improvements planned for the `UnrealXistTools` repository.

## High Priority

-   [ ] **Extensive Tests**: Create comprehensive tests for PowerShell modules, specifically:
    -   `Modules/INI.psm1`
    -   `Modules/UE.psm1`
    -   `Modules/P4.psm1`
    -   Existing tests are sparse (only `Tests/Test_P4_ParseFileType.ps1`).
-   [ ] **Improve Documentation**:
    -   Expand `README.md` with more examples.
    -   Add inline help to all `.ps1` and `.psm1` files.
    -   Generate API documentation if possible.

## Medium Priority

-   [ ] **CI/CD Pipeline**:
    -   Set up GitHub Actions to run tests on push/PR.
    -   Validate PowerShell script syntax (PSScriptAnalyzer).
-   [ ] **Refactoring**:
    -   Ensure consistent error handling across all scripts.
    -   Standardize parameter naming conventions.
    -   Move common logic from root scripts into `Modules/`.

## Low Priority (Ideas)

-   [ ] **Cross-Platform Verification**:
    -   Ensure all "Linux + Mac + Windows" scripts are truly continuously tested on all platforms.
-   [ ] **Distribution**:
    -   Consider publishing as a PowerShell Gallery module.
