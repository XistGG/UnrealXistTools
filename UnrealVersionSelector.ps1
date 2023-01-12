#
# UnrealVersionSelector.ps1
#
# See: https://github.com/XistGG/UnrealXistTools/
#
# Usage:
#
#   UnrealVersionSelector.ps1 -projectfiles
#     - Regenerate Project Files for project in current directory
#
#   UnrealVersionSelector.ps1 -projectfiles MyGame.uproject
#     - Regenerate Project Files for project MyGame.uproject
#

[CmdletBinding()]
param(
    [switch]$Help,
    [switch]$Editor,
    [switch]$Game,
    [switch]$ProjectFiles,
    [switch]$SwitchVersion,
    [switch]$SwitchVersionSilent,
    [switch]$Quiet,
    [switch]$Force,
    [Parameter()] $UProjectFile,
    [Parameter(ValueFromRemainingArguments=$true)] $VarArgs
)

$ScriptName = $MyInvocation.MyCommand.Name


################################################################################
###  Find UnrealVersionSelector.exe on this host
################################################################################

# defer to Environment if var is set
$UnrealVersionSelector = $env:UnrealVersionSelector


function IsUnrealVersionSelectorValid
{
    param ([string]$UVS)
    if ($UVS -ne '')
    {
        #Write-Host "Test Path: '$UVS'"
        return !!(Test-Path -Path $UVS -PathType Leaf)
    }
    return $false
}


# If there isn't already a known Unreal Version Selector
if (!(&IsUnrealVersionSelectorValid $UnrealVersionSelector))
{
    # Search the Windows Registry to find the Epic Games Launcher version
    $RegistryItem = Get-ItemProperty "Registry::HKEY_CLASSES_ROOT\Unreal.ProjectFile\shell\open\command" 2> $null
    if (!$RegistryItem)
    {
        throw "Unreal.ProjectFile Registry Keys NOT FOUND! You must set the UnrealVersionSelector environment variable"
    }

    # Parse the default command line to get the location of Unreal Version Selector
    $RegistryCommand = $RegistryItem.'(default)'
    if ($RegistryCommand -cmatch '^\s*"([^"]+)"')
    {
        $UnrealVersionSelector = $Matches[1]
    }
    else
    {
        $UnrealVersionSelector = ($RegistryCommand -split ' ')[0]
    }

    # If there is still no valid Unreal Version Selector, that's a fatal error
    if (!(&IsUnrealVersionSelectorValid $UnrealVersionSelector))
    {
        # We needed to parse the registry to find Unreal Version Selector, but the value was unexpected
        throw "Failed to parse Registry Value: $RegistryCommand"
    }
}


################################################################################
###  Expand $UProjectFile argument into absolute path of a UProject
################################################################################

# If user didn't specify a project file, default to current directory
if (!$PSBoundParameters.ContainsKey('UProjectFile'))
{
    $UProjectFile = '.'
}
. $PSScriptRoot\UProjectFile.ps1


################################################################################
###  Run Unreal Version Selector
################################################################################

if ($SwitchVersionSilent -or $SwitchVersion)
{
    # When trying to switch Engine version, it requires modifying the uproject file
    # If it's set to read-only, UVS will fail with code 1 and not give a very good error message.
    # Check for that here and throw an explicit exception unless -force is specified,
    # in which case forcefully remove the read only bit from the uproject file.

    if ((Get-ChildItem $UProjectFile).IsReadOnly)
    {
        if (!$Force)
        {
            throw "Your project file is read-only; check it out or make it writable, or use -force switch: $UProjectFile"
        }

        # -force flag is set; explicitly make $UProjectFile writable
        (Get-ChildItem $UProjectFile).IsReadOnly = $false

        # Print a warning message so it's obvious we did this
        Write-Warning "-force removed read only attribute from $UProjectFile"
    }
}


$process = $null

if ($SwitchVersionSilent)
{
    # You MUST provide the Engine Dir argument for -SwitchVersionSilent
    # It must be the path to the "Engine" folder root (its parent folder)
    if ($VarArgs.count -eq 0)
    {
        Write-Error "You must specify the EngineRootDir for -SwitchVersionSilent"
        throw "Usage: $ScriptName -switchversionsilent UProjectFile EngineRootDir"
    }
    $EngineDir = $VarArgs[0]

    # Test $EngineDir to make sure it is a directory and it looks like
    # it contains UE Engine/Binaries generated files
    if (!(Test-Path -Path $EngineDir -PathType Container) -or !(Test-Path -Path "$EngineDir/Engine/Binaries" -PathType Container))
    {
        throw "Invalid EngineDir specified: $EngineDir"
    }

    Write-Host "EXEC: $UnrealVersionSelector -switchversionsilent $UProjectFile $EngineDir"
    $process = Start-Process -PassThru -FilePath $UnrealVersionSelector -ArgumentList "-switchversionsilent",$UProjectFile,$EngineDir
}
elseif ($SwitchVersion)
{
    Write-Host "EXEC: $UnrealVersionSelector -switchversion $UProjectFile"
    $process = Start-Process -PassThru -FilePath $UnrealVersionSelector -ArgumentList "-switchversion",$UProjectFile
}
elseif ($ProjectFiles)
{
    Write-Host "EXEC: $UnrealVersionSelector -projectfiles $UProjectFile"
    $process = Start-Process -PassThru -FilePath $UnrealVersionSelector -ArgumentList "-projectfiles",$UProjectFile
}
elseif ($Editor)
{
    Write-Host "EXEC: $UnrealVersionSelector -editor $UProjectFile"
    $process = Start-Process -PassThru -FilePath $UnrealVersionSelector -ArgumentList "-editor",$UProjectFile -WorkingDirectory $UProjectDirectory
}
elseif ($Game)
{
    Write-Host "EXEC: $UnrealVersionSelector -game $UProjectFile"
    $process = Start-Process -PassThru -FilePath $UnrealVersionSelector -ArgumentList "-game",$UProjectFile -WorkingDirectory $UProjectDirectory
}


if ($process)
{
    # Wait for the process we started to exit
    # (NOTE: If it spawns child processes, we do NOT wait for those; sometimes -switchversion does funky stuff... (?))
    Wait-Process -InputObject $process
    $e = $process.ExitCode

    if ($e -ne 0)
    {
        Write-Warning "Exit Code $e"
    }
    else
    {
        Write-Host "Exit Code $e"
    }

    Write-Host ""
    exit $e
}


################################################################################
###  Help
################################################################################

Write-Host @'

Build Usages:

    Usage: $ScriptName -projectfiles MyGame.uproject
    Usage: $ScriptName -switchversion MyGame.uproject [-force]
    Usage: $ScriptName -switchversionsilent MyGame.uproject /path/to/EngineRoot [-force]

Play Usages:

    Usage: $ScriptName -editor MyGame.uproject
    Usage: $ScriptName -game MyGame.uproject

You can sometimes omit "MyGame.uproject" from the command-line.
It is optional if the Project Directory is named the same as the
uproject name.  For example these project folders will work
without having to explicitly specify "MyGame.uproject":

    C:/Path/to/Game/Game.uproject
               ^^^^ ^^^^

For a project directory like the above "C:/Path/to/Game",
the following usages will also work:

    cd C:/Path/to/Game
    $ScriptName -projectfiles

    cd C:/
    $ScriptName -projectfiles Path/to/Game

'@
