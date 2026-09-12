# Decode Analysis: RunTests.ps1

## Definition
**Path**: `RunTests.ps1`

### Parameters
- `-Path <string[]>`: Test files or directories to run. Defaults to the repository's
  `Tests/` directory, independent of the caller's working directory.

## Usages
- `.github/workflows/tests.yml`: Windows, macOS, and Ubuntu CI.
- `Tests/RunTests.Tests.ps1`: Subprocess tests of runner exit behavior.
- See the README's Testing section for local commands.

## Invocation Details
Requires PowerShell 7+. Run with `pwsh -NoLogo -NoProfile -NonInteractive -File ./RunTests.ps1`.

## Observations
- Installs Pester **5.7.1** for the current user if unavailable and imports it explicitly with `-Force`.
- Uses Pester 5 configuration with detailed output, pass-through results, and `Run.Throw`.
- Test, discovery, and setup failures produce a nonzero process exit code.
- Rejects an empty suite instead of silently succeeding.
