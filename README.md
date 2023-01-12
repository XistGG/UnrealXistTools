
# Unreal Xist Tools

Xist's Unreal C++ Build & Dev Tools.  Requires PowerShell 7+.

Main Branch: https://github.com/XistGG/UnrealXistTools/


## Setup

- Make sure you are using PowerShell 7+
  - `winget install Microsoft.PowerShell`
- Clone this repository
- Add this repository clone folder to your `$env:PATH`


# Build Tools

- [UProjectClean](#UProjectClean)
  - Completely Clean/Reset Repo/Depot
  - Removes all generated C++ Build files
- [UnrealVersionSelector](#UnrealVersionSelector)


# UProjectClean

- Delete all `Binaries` (generated data)
- Delete all `Intermediate` (generated data)
- Generate Project Files

### Usage Examples

```powershell
UProjectClean.ps1 MyGame.uproject
```

```powershell
UProjectClean.ps1
```

The above works if your project folder name is the same as your uproject name (e.g. 'Foo/Foo.uproject')


# UnrealVersionSelector

- Find and execute Epic Launcher version of `UnrealVersionSelector`
  - Allow dev to use relative paths
  - Send absolute paths to Epic UVS, which requires them

### Usage Example

```powershell
UnrealVersionSelector.ps1 -projectfiles MyGame.uproject
```
