#!/usr/bin/env pwsh
#
# MigrateUEMarketplacePlugin.ps1
#
# See: https://github.com/XistGG/UnrealXistTools/
#
# This will migrate an engine plugin from the UE Marketplace from whatever engine version
# that plugin was released to and into your own custom engine.
#
# This runs UAT from your custom engine to BuildPlugin into a temporary directory, and
# if that succeeds, it installs that into your custom engine's Marketplace directory.
#
# The -From and -To parameters must exist and must be the root of the respective
# Unreal Engines.  The error messages will hopefully help you determine the appropriate
# values for these on your system.
#
# Now that UE Marketplace moved to Fab, the plugin directory names are annoying.
# To get around this, use the -PluginSourceName parameter.
#
# Example usage:
#
#   MigrateUEMarketplacePlugin.ps1 -Plugin AutoSizeComments -PluginSourceName AutoSizec06247d73541V16 -From "E:/EpicLauncher/UE_5.5" -To "E:/MyEngine_5.5" -Debug -Force
#   MigrateUEMarketplacePlugin.ps1 -Plugin BlueprintAssist -PluginSourceName Blueprin5dd30dcb4d35V14 -From "E:/EpicLauncher/UE_5.5" -To "E:/MyEngine_5.5" -Debug -Force
#

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$NoCleanup,
    [Parameter(Mandatory)]$Plugin,
    [Parameter(Mandatory)]$From,
    [Parameter(Mandatory)]$To,
    [string]$PluginSourceName = "",  # Defaults to same as $Plugin
    [string]$PluginDestinationName = "",  # Defaults to same as $Plugin
    [switch]$ToThirdParty
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

# Import the UE helper module
Import-Module -Name $PSScriptRoot/Modules/UE.psm1

################################################################################
##  Validate Input
################################################################################

Write-Debug "Copy [$Plugin] From [$From] To [$To]"

if (!$Plugin -or $Plugin -eq "")
{
    throw "-Plugin must be set"
}

$FromItem = Get-Item $From
if (!$FromItem -or !$FromItem.PSIsContainer)
{
    throw "-From must be an existing directory"
}

$ToItem = Get-Item $To
if (!$ToItem -or !$ToItem.PSIsContainer)
{
    throw "-To must be an existing directory"
}


# Make sure $ToPluginSubdir is either 'ThirdParty' or the default 'Marketplace'
if ($ToThirdParty)
{
    $ToPluginSubdir = 'ThirdParty'
}
else
{
    $ToPluginSubdir = 'Marketplace'
}


# If $PluginSourceName and/or $PluginDestinationName were not explicitly configured,
# they default to the same value as $Plugin
#
# With the migration of the Marketplace to Fab, the $PluginSourceName is seemingly
# now a randomish string of letters.

if ($PluginSourceName -eq "")
{
    $PluginSourceName = $Plugin
}

if ($PluginDestinationName -eq "")
{
    $PluginDestinationName = $Plugin
}


################################################################################
##  Init Directory Vars
################################################################################

$FromEngineDir = Join-Path $FromItem.FullName "Engine"
$ToEngineDir = Join-Path $ToItem.FullName "Engine"

$ToEngineConfig =& UE_GetEngineConfig -EngineDir $ToEngineDir  # from Modules/UE.psm1
$ToUAT = $ToEngineConfig.UAT  # path to "RunUAT.bat" on Windows; "RunUAT.sh" on Linux+Mac

$FromPluginDir = Join-Path $FromEngineDir "Plugins" "Marketplace" $PluginSourceName
$ToPluginDir = Join-Path $ToEngineDir "Plugins" $ToPluginSubdir $PluginDestinationName


################################################################################
##  Check validity of Plugin Source
################################################################################

$FromPluginDirItem = Get-Item $FromPluginDir

if (!$FromPluginDirItem -or !$FromPluginDirItem.PSIsContainer)
{
    throw "-Plugin source directory does not exist: [$FromPluginDir]"
}

$FromUPlugin = Join-Path $FromPluginDir "${Plugin}.uplugin"
$FromUPluginItem = Get-Item $FromUPlugin

if (!$FromUPluginItem -or !$FromUPluginItem.Exists)
{
    throw "-Plugin .uplugin file does not exist: [$FromUPlugin]"
}


################################################################################
##  Remove destination Plugin, if any
################################################################################

$ToPluginDirItem = Get-Item $ToPluginDir 2> $null

if ($ToPluginDirItem -and $ToPluginDirItem.Exists)
{
    if (!$Force)
    {
        throw "Destination Plugin directory exists [$ToPluginDir]. Use -Force to remove it, or remove it yourself and try again."
    }

    # Try to remove the dir
    Remove-Item -Path $ToPluginDir -Force -Recurse

    # Check to make sure it's actually removed
    $ToPluginDirItem = Get-Item $ToPluginDir 2> $null
    if ($ToPluginDirItem -and $ToPluginDirItem.Exists)
    {
        throw "Failed to remove existing directory [$ToPluginDir]"
    }
}


################################################################################
##  Check validity of $ToUAT
################################################################################

$ToUATItem = Get-Item $ToUAT

if (!$ToUATItem -or !$ToUATItem.Exists)
{
    throw "Cannot find -To UAT at [$ToUAT]"
}


################################################################################
##  Create Temp Directory
################################################################################

$TempRoot = [System.IO.Path]::GetTempPath()
[string] $TempName = [System.Guid]::NewGuid()

$TempDirPath = Join-Path $TempRoot $TempName

Write-Debug "Creating temp directory: [$TempDirPath]"
$TempDir = New-Item -ItemType Directory -Path $TempDirPath


################################################################################
##  Migrate Plugin
################################################################################

$NeedCleanup = $true

try
{
    Write-Host "Building $Plugin for $To"

    # Exec UAT BuildPlugin

    Write-Debug "EXEC: $ToUAT BuildPlugin -Plugin=`"$FromUPlugin`" -Package=`"$TempDirPath`" -CreateSubFolder"
    $Process = Start-Process -NoNewWindow -PassThru -FilePath $ToUAT -ArgumentList "BuildPlugin","-Plugin=`"$FromUPlugin`"","-Package=`"$TempDirPath`"","-CreateSubFolder"

    if (!$Process)
    {
        throw "Cannot execute UAT"
    }

    Wait-Process -InputObject $Process
    $e = $Process.ExitCode

    if ($e -ne 0)
    {
        throw "UAT exited with error code $e"
    }

    # Make sure the parent directory of the proposed $ToPluginDir exists.
    # Make it if it does not.

    $ParentDirPath = Split-Path $ToPluginDir
    $ParentDir = Get-Item -Path $ParentDirPath 2> $null  # squelch errors

    if (!$ParentDir -or !$ParentDir.Exists)
    {
        $ParentDirItem = New-Item -Path $ParentDirPath -Type 'directory'
        if (!$ParentDirItem -or !$ParentDirItem.Exists)
        {
            throw "Cannot create directory [$ParentDirPath]"
        }
    }

    # Move the newly built plugin to the destination Engine

    Write-Debug "Moving [$TempDirPath] to [$ToPluginDir]"
    Move-Item -Path $TempDirPath -Destination $ToPluginDir

    $NeedCleanup = $false
}

################################################################################
##  Clean up temp directory
################################################################################

finally
{
    if ($NeedCleanup -and !$NoCleanup)
    {
        Write-Debug "Cleaning up temp files..."
        Remove-Item -Path $TempDirPath -Force -Recurse
    }
}
