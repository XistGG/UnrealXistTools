# UnrealXistTools Agent Documentation

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
