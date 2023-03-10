
# Unreal Xist Tools

Xist's Unreal C++ Build & Dev Tools.  Requires PowerShell 7+.

Main Branch: https://github.com/XistGG/UnrealXistTools/


## Setup

- Make sure you are using PowerShell 7+
  - `winget install Microsoft.PowerShell`
- Clone this repository
- Add this repository clone folder to your `$env:PATH`


# Build Tools

- [UEngine.ps1](#uengineps1)
  - View and Modify Custom Engine Builds in Windows Registry
- [UProjectClean.ps1](#uprojectcleanps1)
  - Completely Clean/Reset Repo/Depot
  - Removes all generated C++ Build files
  - Regenerate Project Files
- [UProjectFile.ps1](#uprojectfileps1)
- [UProject.ps1](#uprojectps1)
- [UnrealVersionSelector.ps1](#unrealversionselectorps1)
  - Easy-to-use interface to Epic's UnrealVersionSelector.exe


# P4 Tools

- [P4EncodePath.ps1](#p4encodepathps1)
  - Encode (or `-Decode`) paths for P4
- [P4ImportBulk.ps1](#p4importbulkps1)
  - Import a massive number of files into a new depot without breaking P4
    (tested by importing 800k+ files from UDN P4 `//UE5/Release-5.2`)
- [P4Info.ps1](#p4infops1)
  - Makes it real easy to extract `p4 info` values


# UEngine.ps1

[view source: UEngine.ps1](https://github.com/XistGG/UnrealXistTools/blob/main/UEngine.ps1)

- By default selects the engine used by the current or named project
- `-List` lists all available custom engines
- `-Name` selects from available custom engines
- `-NewName` renames an engine to your choice of names
- `-Project` selects the engine associated with the given .uproject

See `-Help` for more Usage info.

### Usage Examples

```powershell
UEngine.ps1 -List
```

```powershell
UEngine.ps1 OldRandomGUIDName -NewName MyEngine
```


# UProjectClean.ps1

[view source: UProjectClean.ps1](https://github.com/XistGG/UnrealXistTools/blob/main/UProjectClean.ps1)

- Delete all `Binaries` (generated data)
- Delete all `Intermediate` (generated data)
- Delete all `*.sln` (generated data)
- Delete all `.idea` (if you set `-Idea` switch)
- Delete all `DerivedDataCache` (if you set `-DDC` switch)
- Generate Project Files

### Usage Examples

Clean the project in the current directory:

```powershell
UProjectClean.ps1 -Debug
```

Clean a specific `MyGame.uproject`:

```powershell
UProjectClean.ps1 -Debug MyGame.uproject
```


# UProjectFile.ps1

[view source: UProjectFile.ps1](https://github.com/XistGG/UnrealXistTools/blob/main/UProjectFile.ps1)

Provides a default `$UProjectFile` based on the current directory.
If you do not explicitly set a -Path, it will auto-guess the
appropriate .uproject file in the current directory.

### Usage Examples

Set `$UProjectFile` to the current directory's default value.

```powershell
UProjectFile.ps1 -Debug
```

Set `$UProjectFile` to the default one in the `path/to/Project/` directory.

```powershell
UProjectFile.ps1 -Debug path/to/Project/
```

Set `$UProjectFile` to be a specific .uproject

```powershell
UProjectFile.ps1 -Debug path/to/Project/Name.uproject
```

# UProject.ps1

[view source: UProject.ps1](https://github.com/XistGG/UnrealXistTools/blob/main/UProject.ps1)

Returns JSON parsed contents of `$UProjectFile` as a PowerShell Object


# UnrealVersionSelector.ps1

[view source: UnrealVersionSelector.ps1](https://github.com/XistGG/UnrealXistTools/blob/main/UnrealVersionSelector.ps1)

- Allows developer to refer to `.uproject` files via relative paths
- Infers the name of `.uproject` files based on current directory
- Executes Epic's `UnrealVersionSelector.exe` for base functionality

See `-Help` for Usage.

### Usage Examples

#### Generate project files

```powershell
UnrealVersionSelector.ps1 -ProjectFiles
```

#### Choose which Engine to use

```powershell
UnrealVersionSelector.ps1 -SwitchVersion
```

##### Choose a Specific Engine

```powershell
UnrealVersionSelector.ps1 -SwitchVersionSilent /Project/Root/Engine/Binaries/../..
```


# P4EncodePath.ps1

[view source: P4EncodePath.ps1](https://github.com/XistGG/UnrealXistTools/blob/main/P4EncodePath.ps1)

Encodes or Decodes a P4 path.  See `-Help` for more details.

See [P4 filespecs](https://www.perforce.com/manuals/cmdref/Content/CmdRef/filespecs.html)
for more info regarding P4 path encoding requirements.

See `-Help` for Usage.

# P4ImportBulk.ps1

[view source: P4ImportBulk.ps1](https://github.com/XistGG/UnrealXistTools/blob/main/P4ImportBulk.ps1)

Import a massive number of files into a new depot without breaking P4.

As of Jan-2023 I am unable to get P4 to successfully import UDN in one commit.
Perhaps it is related to RAM availability?

With this script, I can break the 800k+ files into batches and submit those,
which works great.

See `-Help` for Usage.

# P4Info.ps1

[view source: P4Info.ps1](https://github.com/XistGG/UnrealXistTools/blob/main/P4Info.ps1)

Extracts `p4 info` output into a Dictionary, which it returns as the result.

You can then grab specific keys if you want, for example:

```powershell
$P4Username = (P4Info.ps1)."User name"
```

You can also use this to initialize `.p4config` files like:

```powershell
P4Info.ps1 -Config > .p4config
```

Try the `-Debug` switch to see the parse info.

