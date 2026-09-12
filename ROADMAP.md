# UnrealXistTools Roadmap

This document outlines the future work and improvements planned for the `UnrealXistTools` repository.

## High Priority

-   [ ] **Extensive Tests**:
    -   Analyze `.ps1` scripts for testability and coverage requirements.
    -   Implement tests for `.ps1` scripts.
    -   Create comprehensive tests for PowerShell modules, specifically:
        -   `Modules/INI.psm1`
        -   `Modules/UE.psm1`
        -   `Modules/P4.psm1`
        -   Pester 5 suites cover the core modules and runner; expand edge-case and top-level script coverage.
-   [ ] **Improve Documentation**:
    -   Expand `README.md` with more examples.
    -   Add inline help (Get-Help) to all `.ps1` and `.psm1` files.
    -   Generate API documentation if possible.
    -   **JetBrains Toolbox Setup**: Document script name requirements (e.g. usage of `Rider1` vs `rider`) to avoid conflicts with `Rider.ps1` (and similarly for PyCharm/Idea).

## Medium Priority

-   [ ] **CI/CD Pipeline**:
    -   [x] GitHub Actions runs Pester on Windows, macOS, and Ubuntu for pushes/PRs.
    -   Validate PowerShell script syntax (PSScriptAnalyzer).
-   [ ] **Refactoring**:
    -   Ensure consistent error handling across all scripts.
    -   Standardize parameter naming conventions.
    -   Move common logic from root scripts into `Modules/` for better testability.

## Low Priority (Ideas)

-   [ ] **Cross-Platform Verification**:
    -   Ensure all "Linux + Mac + Windows" scripts are truly continuously tested on all platforms.
-   [ ] **Distribution**:
    -   Consider publishing as a PowerShell Gallery module.
