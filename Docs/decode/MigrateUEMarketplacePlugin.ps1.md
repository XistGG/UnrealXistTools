# Decode Analyis: MigrateUEMarketplacePlugin.ps1

## Definition
**Path**: `MigrateUEMarketplacePlugin.ps1`

### Parameters
- `[switch]$Force`: Overwrite existing files/directories.
- `[switch]$NoCleanup`: Leave temporary directories behind for debugging.
- `[Parameter(Mandatory)]$Plugin`: Name of the Plugin.
- `[Parameter(Mandatory)]$From`: Source Engine directory root.
- `[Parameter(Mandatory)]$To`: Destination Engine directory root.
- `[string]$PluginSourceName`: (Optional) If Marketplace naming differs from Plugin name.
- `[string]$PluginDestinationName`: (Optional) If destination name differs from Plugin name.
- `[switch]$ToThirdParty`: Install to `ThirdParty` instead of `Marketplace` plugins folder.

## Usages
No usages found in the workspace (other than documentation/README).

## Invocation Details
This script appears to be a standalone tool intended to be run manually by the user.

## Observations
- Helper module `[Modules/UE.psm1](../../Modules/UE.psm1)` is imported.
- Checks `[PSVersionCheck.ps1](../../PSVersionCheck.ps1)`.
- Creates temporary directories and cleans up using `try/finally`.
