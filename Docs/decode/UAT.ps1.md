# Decode Analysis: UAT.ps1

## Definition
**Path**: `UAT.ps1`

### Parameters
- `[string]$Config`: Build config (default: "Development").
- `[string]$Target`: Target name (default: "LyraGameEOS").
- `[string]$Module`: Optional module filter.
- `[switch]$Cook`: Cook content.
- `[switch]$Build`: Build binaries.
- `[switch]$Run`: Run the cooked game.
- `[switch]$Server`: Run server.
- `[switch]$Stage`: Stage.
- `[switch]$FullCook`: Force full cook.
- `[switch]$BuildMachine`: Add `-BuildMachine` flag.
- `[switch]$CrashReporter`: Add `-CrashReporter` flag.
- `[switch]$Distribution`: Add `-Distribution` flag.
- `[Parameter(Position = 0)]$Path`: Project path.

## Usages
No usages found in the workspace (other than documentation/README).

## Invocation Details
Standalone tool to wrap Unreal Automation Tool (UAT).

## Observations
- Automatically resolves `RunUAT.bat` path using project association.
