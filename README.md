
# Unreal Xist Tools

Xist's Unreal C++ Build & Dev Tools.  Requires PowerShell 7+.

Main Branch: https://github.com/XistGG/UnrealXistTools/

UnrealXistTools is intended to work on both Windows and Mac.
Each tool below specifies the exact compatibility (some are Windows only).

It should also mostly work on Linux, though I haven't tested it yet.

## Setup

- Make sure you are using PowerShell 7+
  - Mac: `brew install --cask powershell`
  - Windows: `winget install Microsoft.PowerShell`
    *(issues? [try this fix](https://github.com/microsoft/winget-cli/issues/3652#issuecomment-1909141458))*
- Clone this repository
- Add this repository clone folder to your `$env:PATH`

### PowerShell Execution Policy Notice

The first time you try to set this up, you may get an error regarding PowerShell execution policy.

By default, Windows wants to protect you from yourself.
To configure your system to run PowerShell scripts, you need to explicitly set your
PowerShell execution policy.

For example if you want to use my settings, you can do:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Mine is set to `RemoteSigned` and these scripts all run fine.
Note that you must be responsible to ensure you only run PowerShell that you trust!

Also I am no PowerShell security expert, so if you are concerned about this,
I encourage you to research it further on your own.


# Build Tools

- [UAT.ps1](#uatps1)
  - Easy interface to `RunUAT.*` tools
- [UProjectClean.ps1](#uprojectcleanps1)
  - Completely Clean/Reset Repo/Depot
  - Removes all generated C++ Build files
  - Regenerate Project Files
- [UEdit.ps1](#ueditps1)
  - Edit a project in Unreal Editor
- [UnrealVersionSelector.ps1](#unrealversionselectorps1)
  - Easy-to-use interface to Epic's UnrealVersionSelector.exe


# IDE Tools

- [Rider.ps1](#riderps1)
  - Edit a project in Rider
- [VS.ps1](#vsps1)
  - Edit a project in Visual Studio


# Engine Tools

- [MigrateUEMarketplacePlugin.ps1](#migrateuemarketplacepluginps1)
  - Migrate a C++ plugin from one Engine version to another
- [UEngine.ps1](#uengineps1)
  - View and Modify Custom Engine Builds *(read/write Epic's Windows registry keys)*


# Project Tools

- [UProject.ps1](#uprojectps1)
  - Get Project Settings
- [UProjectFile.ps1](#uprojectfileps1)
  - Get the `.uproject` file associated with a path (current directory by default)
- [UProjectSln.ps1](#uprojectslnps1)
  - Get the `.sln` file associated with a path (current directory by default)


# P4 Tools

- [P4AutoResolveToDefaultCL.ps1](#p4autoresolvetodefaultclps1)
  - Given a CL with a massive number of files to be resolved, auto-resolve (no merging)
    everything we can into the default CL, leaving only those files requiring manual
    merging in the original CL.
  - Very helpful for Engine upgrades (5.4 -> 5.5 was 150k+ files to resolve!)
- [P4Config.ps1](#p4configps1)
  - Locate and import `.p4config` in the given Path or one of its parents
  - `-Export` the config to the system environment *(optional)*
  - Used by
    [`Rider.ps1`](#riderps1)
    and [`VS.ps1`](#vsps1)
    to set the P4 environment specific to the given project being opened
    so you don't have to store duplicate P4 settings in IDE configs.
- [P4EncodePath.ps1](#p4encodepathps1)
  - Encode (or `-Decode`) paths for P4
- [P4FStat.ps1](#p4fstatps1)
  - Provides easy access to `p4 fstat file` output
  - `$(P4FStat.ps1 myfile).headType` (== `text+w` for example)
- [P4ImportBulk.ps1](#p4importbulkps1)
  - Import a massive number of files into a new depot without breaking P4
    (tested by importing 800k+ files from UDN P4 `//UE5/Release-5.2`)
- [P4Info.ps1](#p4infops1)
  - Makes it real easy to extract `p4 info` values
- [P4ObliterateIgnoredFiles.ps1](#p4obliterateignoredfilesps1)
  - Recursively scan the given path, searching for files that were added to p4
    but are supposed to be ignored, and obliterate any such files from the p4 server.
    - Note: obliterate requires admin access to the p4 server.
- [P4Reunshelve.ps1](#p4reunshelveps1)
  - Easy repetitive "revert changes and re-unshelve"
  - Useful when coding on 1 workstation and testing on multiple other workstations

--------------------------------------------------------------------------------

# UAT.ps1

[view source: UAT.ps1](https://github.com/XistGG/UnrealXistTools/blob/main/UAT.ps1)

Compatibility: Windows + Mac

This is an easy interface to `RunUAT.bat` and/or `RunUAT.sh` which auto-computes
a lot of otherwise required command-line arguments to those tools.

### Usage Examples

Build, cook, stage and run the `LyraGameEOS` target from `Lyra.uproject` in the `Development` configuration:

```powershell
UAT.ps1 Lyra.uproject -Config Development -Target LyraGameEOS -Build -Cook -Stage -Run
```


# UProjectClean.ps1

[view source: UProjectClean.ps1](https://github.com/XistGG/UnrealXistTools/blob/main/UProjectClean.ps1)

Compatibility: Windows only

- Delete all `Binaries` (generated data)
- Delete all `Intermediate` (generated data)
- Delete all `*.sln` (generated data)
- Delete all `.idea` (if you set `-Idea` switch or `-Nuke`)
- Delete `DerivedDataCache` (if you set `-DDC` switch or `-Nuke`)
- Delete `Saved` (if you set `-Saved` switch or `-Nuke`)
- Generate Project Files

Supports the `-Debug` flag, add it to any command to gain more insight.

### Usage Examples

Clean the project in the current directory:
```powershell
UProjectClean.ps1
```

Clean a specific `MyGame.uproject`:
```powershell
UProjectClean.ps1 MyGame.uproject
```

Clean (NUKE) the project in the current directory: *(implies flags `-DDC`, `-Idea`, `-Saved`)*
```powershell
UProjectClean.ps1 -Nuke
```


# UEdit.ps1

[view source: UEdit.ps1](https://github.com/XistGG/UnrealXistTools/blob/main/UEdit.ps1)

Compatibility: Windows only

Start Unreal Editor: Open the `.uproject` associated with the current directory.

Alias for `UnrealVersionSelector.ps1 -Editor $(UProjectFile.ps1 -Path:$Path).FullName`

Note that as this uses `UnrealVersionSelector` under the hood, you must have compiled your
editor and project in `Development Editor` mode.  When opening a project in editor, the
underlying UVS requires that we use a Development editor.

Supports the `-Debug` flag, add it to any command to gain more insight.


### Usage Examples

Open the `.uproject` file in the current directory:
```powershell
UEdit.ps1
```

Open the `.uproject` file in the specified directory:
```powershell
UEdit.ps1 path/to/project
```


# UnrealVersionSelector.ps1

[view source: UnrealVersionSelector.ps1](https://github.com/XistGG/UnrealXistTools/blob/main/UnrealVersionSelector.ps1)

Compatibility: Windows only

- Allows developer to refer to `.uproject` files via relative paths
- Infers the name of `.uproject` files based on current directory
- Executes Epic's `UnrealVersionSelector.exe` for base functionality

Supports the `-Debug` flag, add it to any command to gain more insight.

See `-Help` for Usage.

### Usage Examples

Generate project files:
```powershell
UnrealVersionSelector.ps1 -ProjectFiles
```

Choose which Engine to use:
```powershell
UnrealVersionSelector.ps1 -SwitchVersion
```

Choose a Specific Engine:
```powershell
UnrealVersionSelector.ps1 -SwitchVersionSilent /Project/Root/Engine/Binaries/../..
```


--------------------------------------------------------------------------------


# Rider.ps1

[view source: Rider.ps1](https://github.com/XistGG/UnrealXistTools/blob/main/Rider.ps1)

Compatibility: Mac + Windows

Start Rider: Open the `.uproject` associated with the current directory.

Uses [`P4Config.ps1`](#p4configps1) to search for any relevant `.p4config`
and if one is found, adds the P4 config to the environment for Rider.

Supports the `-Debug` flag, add it to any command to gain more insight.

### Usage Examples

Open the `.uproject` file in the current directory:
```powershell
Rider.ps1
```

Open the `.sln` file in the current directory:
```powershell
Rider.ps1 -sln
```


# VS.ps1

[view source: VS.ps1](https://github.com/XistGG/UnrealXistTools/blob/main/VS.ps1)

Compatibility: Windows only

Start Visual Studio: Open the `.sln` associated with the current directory.

Uses [`P4Config.ps1`](#p4configps1) to search for any relevant `.p4config`
and if one is found, adds the P4 config to the environment for Rider.

Supports the `-Debug` flag, add it to any command to gain more insight.

### Usage Examples

Open the `.sln` file in the current directory:
```powershell
VS.ps1
```

Diff 2 files (for example can be used from `p4v` as the diff tool)
```powershell
VS.ps1 -diff file1 file2
```


--------------------------------------------------------------------------------


# MigrateUEMarketplacePlugin.ps1

[view source: MigrateUEMarketplacePlugin.ps1](https://github.com/XistGG/UnrealXistTools/blob/main/MigrateUEMarketplacePlugin.ps1)

Compatibility: Mac + Windows

Required Arguments:

- `-Plugin` Name
- `-PluginSourceName` Name of this plugin's Fab directory
- `-From` PathToSourceEngineRoot
- `-To` PathToDestinationEngineRoot

Optional Arguments:

- `-PluginDestinationName`
  - By default, the `-Plugin` Name is also used as the `-PluginDestinationName`
  - You can override this to name the plugin directory something different
- `-ToThirdParty`
  - If present, causes the plugin to be migrated to your `Plugins/ThirdParty` directory rather
    than to the default `Plugins/Marketplace`
- `-Debug`
  - If present, this switch causes additional debugging output to be written
- `-Force`
  - If the destination plugin already exists, forcefully remove it and overwrite with the newly built plugin
  - If this switch is not present, the script will abort rather than overwrite an existing plugin

### Usage Examples

```powershell
MigrateUEMarketplacePlugin.ps1 -Plugin AutoSizeComments -PluginSourceName AutoSizec06247d73541V16 -From "E:/EpicLauncher/UE_5.5" -To "E:/MyEngine_5.5" -Debug -Force
MigrateUEMarketplacePlugin.ps1 -Plugin BlueprintAssist -PluginSourceName Blueprin5dd30dcb4d35V14 -From "E:/EpicLauncher/UE_5.5" -To "E:/MyEngine_5.5" -Debug -Force
```

In the above example, you would have told the Epic Games Launcher to install UE 5.5 into
the folder `E:/EpicLauncher/UE_5.5`
and you would have installed these plugins from the UE Marketplace into the UE 5.5 Engine.

These commands would then copy 3 plugins from the UE Marketplace into your custom engine
at `E:/MyEngine_5.5`
including `AutoSizeComments` and `BlueprintAssist`.

**NOTICE:** Since UE Marketplace migrated to Fab, Marketplace plugins are now being installed
into random-looking (probably Fab ID-based) directory names.

In my case it installed them into these weird directories:

| Plugin             | Marketplace Directory                                |
|--------------------|------------------------------------------------------|
| `AutoSizeComments` | Engine/Plugins/Marketplace/`AutoSizec06247d73541V16` |
| `BlueprintAssist`  | Engine/Plugins/Marketplace/`Blueprin5dd30dcb4d35V14` |

Whereas the directory name used to match the plugin name, it no longer does.

Thus, you have to use the `-PluginSourceName` parameter and set it to the name of the Marketplace directory.

Because this is now required, there is also a new optional `-PluginDestinationName` parameter,
which defaults to the same as the Plugin name, but you can set it to this random looking ID
if you want it to be named exactly the same, or choose some other name, etc.  It's up to you.


# UEngine.ps1

[view source: UEngine.ps1](https://github.com/XistGG/UnrealXistTools/blob/main/UEngine.ps1)

Compatibility: Mac + Windows

- By default selects the engine used by the current or named project
- `-List` lists all available custom engines
- `-Name` selects from available custom engines
- `-NewName` renames an engine to your choice of names
- `-UProject` selects the engine associated with the given .uproject
- `-Debug` enables more detailed debug information

See `-Help` for more Usage info.

### Usage Examples

Display a list of all custom engines on this system:
```powershell
UEngine.ps1 -List
```

Rename the `{1234-5678-Random-GUID-Name}` custom engine as `MyEngine`:
```powershell
UEngine.ps1 "{1234-5678-Random-GUID-Name}" -NewName MyEngine
```

Rename the `SomeCustom` custom engine as `OtherCustom` with `-Debug` info:
```powershell
UEngine.ps1 SomeCustom -NewName OtherCustom -Debug
```

Get info about the engine associated with `My.uproject`:
```powershell
UEngine.ps1 -UProject path/to/My.uproject
```

Get info about the engine associated with the `.uproject` in the current directory
with `-Debug` info
*(errors out if there is no `.uproject` in the current directory)*:
```powershell
UEngine.ps1 -Debug
```

--------------------------------------------------------------------------------


# UProject.ps1

[view source: UProject.ps1](https://github.com/XistGG/UnrealXistTools/blob/main/UProject.ps1)

Compatibility: Mac + Windows

Returns JSON parsed contents of `$UProjectFile` as a PowerShell Object

Supports the `-Debug` flag, add it to any command to gain more insight.

### Usage

View the current `.uproject` in terminal:
```powershell
UProject.ps1
```

Get the Engine Association of a specific `.uproject`:
```powershell
$(UProject.ps1 project.uproject).EngineAssociation
```


# UProjectFile.ps1

[view source: UProjectFile.ps1](https://github.com/XistGG/UnrealXistTools/blob/main/UProjectFile.ps1)

Compatibility: Mac + Windows

Returns the `.uproject` file relevant to the `-Path`
(implicit first string parameter, or current directory by default).

Example: `/project/project.uproject`

Supports the `-Debug` switch.
Enable it to see debug info to help you understand how the `.uproject` is being assigned.

### Usage

Select the default `.uproject` for the current directory:
```powershell
UProjectFile.ps1
```

Select the default `.uproject` in the specified directory:
```powershell
UProjectFile.ps1 /project
```

Select a specific `.uproject`:
```powershell
UProjectFile.ps1 project.uproject
```


# UProjectSln.ps1

[view source: UProjectSln.ps1](https://github.com/XistGG/UnrealXistTools/blob/main/UProjectSln.ps1)

Compatibility: Windows only

Returns the `.sln` file relevant to the `-Path`
(implicit first string parameter, or current directory by default).

Example: `/project/project.sln`

Supports the `-Debug` switch.
Enable it to see debug info to help you understand how the `.sln` is being assigned.

### Usage

Select the default `.sln` for the current directory:
```powershell
UProjectSln.ps1
```

Select the default `.sln` in the specified directory:
```powershell
UProjectSln.ps1 /project
```

Select a specific `.sln`:
```powershell
UProjectSln.ps1 project.sln
```


--------------------------------------------------------------------------------

# P4AutoResolveToDefaultCL.ps1 

[view source: P4AutoResolveToDefaultCL.ps1](https://github.com/XistGG/UnrealXistTools/blob/main/P4AutoResolveToDefaultCL.ps1)

Compatibility: Mac + Windows

Given a CL that contains for example an integrate result, where a lot of files
need to be resolved, auto-resolve (no merging) every file that can be auto resolved,
and move it to the default CL.

After running this, the original $CL will contain ONLY files that could not be
auto-resolved, and you'll need to resolve those manually.

This was very useful in upgrading UE 5.4 to UE 5.5, where there were more than 150k
files needing to be resolved, but only a small number actually required manual work.
After running this, the $CL with the difficult-to-resolve files was small enough to
be worked on by humans.

Procedure:
1. Integrate another stream (or do anything requiring tons of resolves).
2. Move all pending file changes to a non-default changelist (e.g. CL#123).
3. MAKE SURE the default changelist is EMPTY, we will be moving things there.
   - If you have pending changes you want to save in the default CL, move them
     to a new CL now.
4. Run P4AutoResolveToDefaultCL.ps1 (this script).
   - All the "easy" stuff that is auto-resolved will be moved to the default CL.
   - All the "hard" stuff that requires manual inspection will remain in CL#123.
5. Manually resolve all the files still in CL#123.
6. Combine CL#123 and the default CL into a single integration CL and submit it.

## Usage

In the example above, we used CL#123, which is done with the following command:

```powershell
P4AutoResolveToDefaultCL.ps1 -CL 123 -Debug
```

As usual, the `-Debug` flag is optional and provides more insight into what the
command is doing when it runs.

# P4Config.ps1

[view source: P4Config.ps1](https://github.com/XistGG/UnrealXistTools/blob/main/P4Config.ps1)

Compatibility: Linux + Mac + Windows

This helpful script can be used before you launch an IDE or other build tool
that requires access to P4 but isn't smart enough to understand that you
have multiple projects existing in the same depot (e.g. a custom Engine *and* a UProject)
and you just want a single `.p4config` in the workspace root that is effective for all
the projects in that workspace.

- `-Path` is an optional path to work in *(Default: Current directory)*
- `-Export` causes the found `.p4config` file *(if any)* to be exported to the system environment
- `-Debug` provides helpful debugging info

## Usage

Find, parse and return the `.p4config` relevant to the current directory:

```powershell
P4Config.ps1 -Debug
```

Find, parse and inject the `.p4config` relevant to the current directory
into the system environment for the current powershell process:

```powershell
P4Config.ps1 -Export -Debug
```


# P4EncodePath.ps1

[view source: P4EncodePath.ps1](https://github.com/XistGG/UnrealXistTools/blob/main/P4EncodePath.ps1)

Compatibility: Linux + Mac + Windows

Encodes or Decodes a P4 path.  See `-Help` for more details.

See [P4 filespecs](https://www.perforce.com/manuals/cmdref/Content/CmdRef/filespecs.html)
for more info regarding P4 path encoding requirements.

See `-Help` for Usage.


# P4FStat.ps1

[view source: P4FStat.ps1](https://github.com/XistGG/UnrealXistTools/blob/main/P4FStat.ps1)

Compatibility: Linux + Mac + Windows

Provides cross-platform object-based access to `p4 fstat filepath` results.

For example if you just run `p4 fstat` manually, you get a text dump that you would then
have to parse, which would work differently depending on what platform you're on.

```text
PS /Users/xist/dev/Xim> p4 fstat RunUAT.sh
... depotFile //Xim/Dev/RunUAT.sh
... clientFile /Users/xist/dev/Xim/RunUAT.sh
... isMapped
... headAction integrate
... headType text+x
... headTime 1734281444
... headRev 3
... headChange 145
... headModTime 1734281422
... pathSource //Xim/Dev
... pathType share
... pathPermissions writable
... effectiveComponentType none
... haveRev 3
```

Conversely, you can use `P4FStat.ps1` which gives you an object result, which works
identically regardless of your current platform:

```text
PS /Users/xist/dev/Xim> P4FStat.ps1 ./RunUAT.sh       

depotFile              : //Xim/Dev/RunUAT.sh
clientFile             : /Users/xist/dev/Xim/RunUAT.sh
isMapped               : True
headAction             : integrate
headType               : text+x
headTime               : 1734281444
headRev                : 3
headChange             : 145
headModTime            : 1734281422
pathSource             : //Xim/Dev
pathType               : share
pathPermissions        : writable
effectiveComponentType : none
haveRev                : 3

PS /Users/xist/dev/Xim> $result = P4FStat.ps1 ./RunUAT.sh
PS /Users/xist/dev/Xim> $result.depotFile                
//Xim/Dev/RunUAT.sh
PS /Users/xist/dev/Xim> $result.headRev  
3
PS /Users/xist/dev/Xim> $result.headType
text+x
```

You can run it on multiple files at a time by passing a array, in which case
the result value is an array of objects:

```text
PS /Users/xist/dev/Xim> $files = Get-ChildItem -Path "RunUAT.*"                                         PS /Users/xist/dev/Xim> $result = P4FStat.ps1 $files           
PS /Users/xist/dev/Xim> $result = P4FStat.ps1 $files
PS /Users/xist/dev/Xim> $result.Count               
2
PS /Users/xist/dev/Xim> $result[0].depotFile
//Xim/Dev/RunUAT.bat
PS /Users/xist/dev/Xim> $result[1].depotFile
//Xim/Dev/RunUAT.sh
```


# P4ImportBulk.ps1

[view source: P4ImportBulk.ps1](https://github.com/XistGG/UnrealXistTools/blob/main/P4ImportBulk.ps1)

Compatibility: Linux + Mac + Windows

Import a massive number of files into a new depot without breaking P4.

As of Jan-2023 I am unable to get P4 to successfully import UDN in one commit.
Perhaps it is related to RAM availability?

With this script, I can break the 800k+ files into batches and submit those,
which works great.

This script has mostly automatic error recovery, so when the Internet hiccups
and you get failures due to connection errors (or any other errors), you can
just restart the script and it will mostly-automatically pick up from the last
successful `p4 add` result.

Supports the `-Debug` flag, add it to any command to gain more insight.

See `-Help` for Usage.


# P4Info.ps1

[view source: P4Info.ps1](https://github.com/XistGG/UnrealXistTools/blob/main/P4Info.ps1)

Compatibility: Linux + Mac + Windows

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


# P4ObliterateIgnoredFiles.ps1

[view source: P4ObliterateIgnoredFiles.ps1](https://github.com/XistGG/UnrealXistTools/blob/main/P4ObliterateIgnoredFiles.ps1)

Compatibility: Mac + Windows

Iterate through the local files, and for every file that SHOULD be ignored,
yet exists in the P4 depot anyway, obliterate it from P4.

Pass the `-y` flag to actually obliterate, otherwise it will just tell you what
it would have done if you had passed the `-y` flag.

Note that you need to have permission to obliterate on the P4 server for this
to work.  (`$env:P4USER = "admin"` will do the trick, if you have the password).

## Usage

This just tells you which files it would obliterate from the current directory
(`-Path .`), and does not actually obliterate:

```powershell
P4ObliterateIgnoredFiles.ps1 -Path .
```

This actually does obliterate any/all files that should be ignored by p4
under the current directory (`-Path .`):

```powershell
P4ObliterateIgnoredFiles.ps1 -Path . -y
```


# P4Reunshelve.ps1

[view source: P4Reunshelve.ps1](https://github.com/XistGG/UnrealXistTools/blob/main/P4Reunshelve.ps1)

Compatibility: Mac + Windows

"Reunshelve" will repeatedly unshelve files into the current workspace.

This script will revert *ALL* changes in your current workspace (it will
prompt you for every file unless you `-Force`) and will then unshelve the
`-SCL` changelist into the current workspace.

I use this for example when I am testing on multiple workstations
simultaneously.  On my primary workstation I make changes, when I'm ready
to test, I shelve the changes, then on the other workstations I run this
script.  The other workstations never have modifications other than the
unshelved changes, I just repeatedly "re-unshelve", discarding whatever
the previous shelved files were and replacing them with the new variant.

```powershell
P4Reunshelve.ps1 -SCL 123
```

The above command will unshelve the files from CL# 123, prompting you
for each and every file before it reverts anything.

```powershell
P4Reunshelve.ps1 -Force -SCL 123
```

**WARNING:** The above command with the `-Force` flag will revert **all changes**
in **all changelists** in your current workspace without prompting you
for confirmation.  It will then unshelve CL# 123.
