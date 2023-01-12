
# Unreal Xist Tools

Xist's Unreal C++ Build & Dev Tools.  Requires PowerShell 7+.

Main Branch: https://github.com/XistGG/UnrealXistTools/


## Setup

- Make sure you are using PowerShell 7+
  - `winget install Microsoft.PowerShell`
- Clone this repository
- Add this repository clone folder to your `$env:PATH`


# Build Tools

- [UProjectClean.ps1](#UProjectClean)
  - Completely Clean/Reset Repo/Depot
  - Removes all generated C++ Build files
- [UnrealVersionSelector.ps1](#UnrealVersionSelector)


# UProjectClean.ps1

- Delete all `Binaries` (generated data)
- Delete all `Intermediate` (generated data)
- Generate Project Files

### Usage Examples

Clean `MyGame.uproject`:

```powershell
UProjectClean.ps1 MyGame.uproject
```

Clean the project in the current directory:

*(requires the directory name to match the uproject name, like `Foo/Foo.uproject`)*

```powershell
UProjectClean.ps1
```


# UnrealVersionSelector.ps1

- Find and execute Epic Launcher version of `UnrealVersionSelector`
  - Allow dev to use relative paths
  - Send absolute paths to Epic UVS, which requires them

### Usage Examples

Generate project files for `MyGame.uproject`:

```powershell
UnrealVersionSelector.ps1 -projectfiles MyGame.uproject
```

Choose which Engine to use for `MyGame.uproject`:

```powershell
UnrealVersionSelector.ps1 -switchversion MyGame.uproject
```

Start Unreal Editor with `MyGame.uproject`:

```powershell
UnrealVersionSelector.ps1 -editor MyGame.uproject
```

Start Game `MyGame.uproject`:

```powershell
UnrealVersionSelector.ps1 -game MyGame.uproject
```

For more info see `UnrealVersionSelector.ps1 -help`
