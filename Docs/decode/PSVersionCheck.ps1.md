# Decode Analysis: PSVersionCheck.ps1

## Definition
**Path**: `PSVersionCheck.ps1`

### Parameters
None. This script is intended to be dot-sourced or executed to verify the PowerShell environment.

## Usages
This script is used by almost every other script in the workspace to ensure PowerShell 7+ is running.

Known usages:
- [GitMakeExecutable.ps1](../../GitMakeExecutable.ps1)
- [MigrateUEMarketplacePlugin.ps1](../../MigrateUEMarketplacePlugin.ps1)
- [P4AutoResolveToDefaultCL.ps1](../../P4AutoResolveToDefaultCL.ps1)
- [P4Config.ps1](../../P4Config.ps1)
- [P4EncodePath.ps1](../../P4EncodePath.ps1)
- [P4FilterIgnored.ps1](../../P4FilterIgnored.ps1)
- [P4FStat.ps1](../../P4FStat.ps1)
- [P4ImportBulk.ps1](../../P4ImportBulk.ps1)
- [P4Info.ps1](../../P4Info.ps1)
- [P4LastGreenBuild.ps1](../../P4LastGreenBuild.ps1)
- [P4ListIgnoredFiles.ps1](../../P4ListIgnoredFiles.ps1)
- [P4NukeCL.ps1](../../P4NukeCL.ps1)
- [P4ObliterateIgnoredFiles.ps1](../../P4ObliterateIgnoredFiles.ps1)
- [P4RemergeLyraExample.ps1](../../P4RemergeLyraExample.ps1)
- [P4RemergeSidestream.ps1](../../P4RemergeSidestream.ps1)
- [P4Reunshelve.ps1](../../P4Reunshelve.ps1)
- [PyCharm.ps1](../../PyCharm.ps1)
- [RefactorUProject.ps1](../../RefactorUProject.ps1)
- [Rider.ps1](../../Rider.ps1)
- [UAT.ps1](../../UAT.ps1)
- [UEdit.ps1](../../UEdit.ps1)
- [UProjectClean.ps1](../../UProjectClean.ps1)
- [UProjectSln.ps1](../../UProjectSln.ps1)
- [UnrealVersionSelector.ps1](../../UnrealVersionSelector.ps1)
- [VS.ps1](../../VS.ps1)

## Invocation Details
Standard invocation at the top of scripts:
```powershell
& $PSScriptRoot/PSVersionCheck.ps1
```

## Observations
- Throws an exception if `$PSVersionTable.PSVersion.Major` is less than 7.
