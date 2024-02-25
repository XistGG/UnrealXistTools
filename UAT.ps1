#!/usr/bin/env pwsh
#
# UAT.ps1
#

[CmdletBinding()]
param(
    [string]$BuildConfig = "Development",
    [string]$BuildProject,  # Inferred by the $UProject by default
    [switch]$Cook,
    [switch]$Help,
    [string]$UProject
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

# Import the UE helper module
Import-Module -Name $PSScriptRoot/Modules/UE.psm1

$ScriptName = $MyInvocation.MyCommand.Name

################################################################################
##  Usage
################################################################################

function Usage
{
    $err = @"

Usage: $ScriptName [-Debug] [-UProject UProject] [-BuildConfig DebugGame] -Cook
       $ScriptName -Help

    -Cook        Cook the project so you can run it outside the Editor.
    -Help        Print this Usage info and exit.

    [-Debug]     If present, prints additional debugging information.
    [-UProject]  (Optional) UProject to your ".uproject" file/directory.
                 Will be auto-computed based on your current dir by default.

"@

    # Write Usage to stderr
    [Console]::Error.WriteLine($err)
    exit 1
}

if ($Help)
{
    & Usage
}

################################################################################
##  Initialization
################################################################################

# Convert the -UProject param (if any) to a $UProjectInfo object
$UProjectInfo =& $PSScriptRoot\UProject.ps1 -Path:$UProject

if (!$UProjectInfo)
{
    throw "You must specify a valid UProject file; see -Help for more info"
}

$UProjectFile = $UProjectInfo._UProjectFile
$EngineAssociation = $UProjectInfo.EngineAssociation

$UProjectFileItem = Get-Item $UProjectFile

# If the user didn't specify an explicit $BuildProject, then use the BaseName
# of the .uproject file as the default value.
if (!$BuildProject -or $BuildProject -eq "")
{
    $BuildProject = $UProjectFileItem.BaseName
    Write-Debug "Using default -BuildProject `"$BuildProject`" given no explicit parameter override"
}

$Engine =& UE_GetEngineByAssociation -UProjectFile $UProjectFile -EngineAssociation $EngineAssociation

if (!$Engine -or !$Engine.Root)
{
    Write-Error "Error determining the Engine directory associated with UProject `"$UProjectFile`", which is associated with Engine `"$EngineAssociation`""
    throw "Invalid Engine Directory `"$($Engine.Root)`""
}

$EngineDir = Join-Path $Engine.Root "Engine"

Write-Debug "Using Engine `"$EngineDir`" for UProject `"$UProjectFile`" EngineAssociation `"$EngineAssociation`""

if (!(Test-Path -Path $EngineDir -PathType Container))
{
    throw "Invalid Engine Directory `"$EngineDir`""
}

$EngineConfig =& UE_GetEngineConfig -BuildConfig:$BuildConfig -EngineDir:$EngineDir

if ($Cook)
{
    $args = @(
        "BuildCookRun", "-Cook", "-SkipStage",
        "-Target=$BuildProject",  # -Target="Foo" FAILS on Mac (!) must be -Target=Foo
        "-Platform=$($EngineConfig.Platform)",  # -Platform="Mac" FAILS (!) must be -Platform=Mac
        "-Project=`"$UProjectFile`"",
        "-UnrealExe=$($EngineConfig.Binaries.EditorCmdName)",  # Mac does not allow quotes!
        "-NoP4"
    )
}
else
{
    & Usage
}

& $EngineConfig.UAT @args
