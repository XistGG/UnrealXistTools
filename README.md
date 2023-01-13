
# Unreal Xist Tools

Xist's Unreal C++ Build & Dev Tools.  Requires PowerShell 7+.

Main Branch: https://github.com/XistGG/UnrealXistTools/


## Setup

- Make sure you are using PowerShell 7+
  - `winget install Microsoft.PowerShell`
- Clone this repository
- Add this repository clone folder to your `$env:PATH`


# Build Tools

- [UProjectClean.ps1](#uprojectcleanps1)
  - Completely Clean/Reset Repo/Depot
  - Removes all generated C++ Build files
  - Regenerate Project Files
- [UnrealVersionSelector.ps1](#unrealversionselectorps1)
  - Easy-to-use interface to Epic's UnrealVersionSelector.exe


# UProjectClean.ps1

- Delete all `Binaries` (generated data)
- Delete all `Intermediate` (generated data)
- Delete all `*.sln` (generated data)
- Generate Project Files

### Usage Examples

Clean the project in the current directory:

```powershell
UProjectClean.ps1
```

Clean a specific `MyGame.uproject`:

```powershell
UProjectClean.ps1 MyGame.uproject
```


# UnrealVersionSelector.ps1

- Allows developer to refer to `.uproject` files via relative paths
- Infers the name of `.uproject` files based on current directory
- Executes Epic's `UnrealVersionSelector.exe` for base functionality


### Usage Examples

#### Generate project files

```powershell
UnrealVersionSelector.ps1 -projectfiles
```

#### Choose which Engine to use

```powershell
UnrealVersionSelector.ps1 -switchversion
```

#### Start Unreal Editor

```powershell
UnrealVersionSelector.ps1 -editor
```

#### Start Game

```powershell
UnrealVersionSelector.ps1 -game
```


### Help

For more info see `UnrealVersionSelector.ps1 -help`
