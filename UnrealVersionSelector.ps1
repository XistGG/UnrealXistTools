#!/usr/bin/env pwsh
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
    [switch]$Force,
    [Parameter()] $UProjectFile,
    [Parameter(ValueFromRemainingArguments=$true)] $VarArgs
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

$UProjectFile = & $PSScriptRoot\UProjectFile.ps1 -Path:$UProjectFile

$ScriptName = $MyInvocation.MyCommand.Name


################################################################################
###  Find UnrealVersionSelector.exe on this host
################################################################################

# defer to Environment if var is set
$UnrealVersionSelector = $env:UnrealVersionSelector


# Test if the $UVS param is an existing file
# @return bool
#
function IsExistingFile
{
    param ([string]$file)
    if ($file -and ($file -ne ''))
    {
        $b = !!(Test-Path -Path $file -PathType Leaf)
        Write-Debug "IsExistingFile Test=${b} Path='$file'"
        return $b
    }
    return $false
}


# Search the Windows Registry to find the Epic Games Launcher version
# For more info: https://x157.github.io/UE5/Windows-Registry-Keys#UVS
#
function GetUnrealVersionSelectorFromRegistry
{
    $RegistryKey = "HKEY_CLASSES_ROOT\Unreal.ProjectFile\shell\open\command"
    $RegistryItem = Get-ItemProperty "Registry::$RegistryKey" 2> $null

    if (!$RegistryItem)
    {
        Write-Debug "Missing Registry::$RegistryKey"
        return $null
    }

    # Parse the default command line to get the location of Unreal Version Selector
    $RegistryCommand = $RegistryItem.'(default)'

    Write-Debug "Read UVS Command from Registry: $RegistryCommand"

    # If the first string is double-quoted, read between the quotes
    if ($RegistryCommand -cmatch '^\s*"([^"]+)"')
    {
        return $Matches[1]
    }

    # If the first string is single-quoted, read between the quotes
    if ($RegistryCommand -cmatch "^\s*'([^']+)'")
    {
        return $Matches[1]
    }

    # No quotes, return the first word
    return ($RegistryCommand -split ' ')[0]
}


# If $UnrealVersionSelector is a file that exists on this system
if (!(&IsExistingFile $UnrealVersionSelector))
{
    # Try to read UVS location from the Windows Registry
    $UnrealVersionSelector = &GetUnrealVersionSelectorFromRegistry

    # If $UnrealVersionSelector is NOT a valid file
    if (!(&IsExistingFile $UnrealVersionSelector))
    {
        # Unable to read UnrealVersionSelector location from Registry
        throw "Unknown UnrealVersionSelector location; if Mac or Linux, please add your platform auto-detect here and submit a PR on Github, I will gladly accept cross-platform support"
    }
}


################################################################################
###  Run Unreal Version Selector
################################################################################

if ($SwitchVersionSilent -or $SwitchVersion)
{
    # When trying to switch Engine version, it requires modifying the uproject file
    # If it's set to read-only, UVS will fail with code 1 and not give a very good error message.
    # Check for that here and throw an explicit exception unless -force is specified,
    # in which case forcefully remove the read only bit from the uproject file.

    if ($UProjectFile.IsReadOnly)
    {
        if (!$Force)
        {
            throw "Your project file is read-only; check it out or make it writable, or use -force switch: $UProjectFile"
        }

        # -force flag is set; explicitly make $UProjectFile writable
        $UProjectFile.IsReadOnly = $false

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
    $process = Start-Process -PassThru -FilePath $UnrealVersionSelector -ArgumentList "-editor",$UProjectFile
}
elseif ($Game)
{
    Write-Host "EXEC: $UnrealVersionSelector -game $UProjectFile"
    $process = Start-Process -PassThru -FilePath $UnrealVersionSelector -ArgumentList "-game",$UProjectFile
}


if ($process)
{
    # Wait for the process we started to exit
    # (NOTE: If it spawns child processes, we do NOT wait for those; sometimes -switchversion does funky stuff... (?))
    Wait-Process -InputObject $process
    $e = $process.ExitCode

    if ($e -eq 0)
    {
        Write-Debug "Exec Success"
        Write-Host ""
    }
    else
    {
        Write-Warning "Exit Code $e"
        Write-Error "$UnrealVersionSelector failed"
    }

    exit $e
}


################################################################################
###  Help
################################################################################

Write-Host @'

Build Usages:

    Usage: $ScriptName -projectfiles MyGame.uproject
    Usage: $ScriptName -switchversion MyGame.uproject [-force]
    Usage: $ScriptName -switchversionsilent MyGame.uproject /path/to/root/Engine/Binaries/../.. [-force]

Play Usages:

    Usage: $ScriptName -editor MyGame.uproject
    Usage: $ScriptName -game MyGame.uproject

'@
