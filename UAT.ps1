#!/usr/bin/env pwsh
#
# UAT.ps1
#
<#
.SYNOPSIS
    Wrapper script for Unreal Automation Tool (UAT) and Unreal Build Tool (UBT).

.DESCRIPTION
    This script provides a convenient wrapper around UAT and UBT for building, cooking, running, and staging Unreal Engine projects.
    It automatically detects the Unreal Engine version associated with the project and uses the appropriate tools.

.PARAMETER Config
    The build configuration ("Development", "DebugGame", "Shipping", etc). Default is "Development".

.PARAMETER Target
    The build target (prefix of your "*.Target.cs" file). Default is "LyraGameEOS".

.PARAMETER Module
    If specified, limit actions to the given Module.

.PARAMETER Cook
    Cook the project so you can run the Game independently of the Editor.
    By default this will cook incrementally for faster execution.

.PARAMETER Build
    Build the project. Required before you can Cook.

.PARAMETER Run
    Run the Target.

.PARAMETER Server
    Run the server.

.PARAMETER Stage
    Stage the project (after cooking) in preparation for packaging.

.PARAMETER FullCook
    If you pass -FullCook then we won't do an incremental cook, and instead will fully cook from scratch (takes longer).

.PARAMETER BuildMachine
    Add -BuildMachine flag.

.PARAMETER CrashReporter
    Add -CrashReporter flag.

.PARAMETER Distribution
    Add -Distribution flag.

.PARAMETER Path
    Path to your ".uproject" file/directory.
    Will be auto-computed based on your current dir by default.

.EXAMPLE
    ./UAT.ps1 -Build
    Builds the project using default configuration and target.

.EXAMPLE
    ./UAT.ps1 -Cook -Run
    Cooks and runs the project.

.EXAMPLE
    ./UAT.ps1 -Target LyraGameSteam -Config Shipping -Build -Cook -Stage
    Builds, cooks, and stages the LyraGameSteam target in Shipping configuration.
#>

[CmdletBinding()]
param(
    [string]$Config = "Development",
    [string]$Target = "LyraGameEOS",
    [string]$Module = $null,
    [switch]$Cook,
    [switch]$Build,
    [switch]$Run,
    [switch]$Server,
    [switch]$Stage,
    [switch]$FullCook,
    [switch]$BuildMachine,
    [switch]$CrashReporter,
    [switch]$Distribution,
    [Parameter(Position = 0)]$Path
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

# Import the UE helper module
Import-Module -Name $PSScriptRoot/Modules/UE.psm1

$ScriptName = $MyInvocation.MyCommand.Name


################################################################################
##  Initialization
################################################################################

try {
    # Convert the -Path param (if any) to a $UProjectInfo object
    $UProjectInfo = & $PSScriptRoot\UProject.ps1 -Path:$Path
}
catch {
    Write-Error "Unable to read the UProject file at -Path `"$Path`", check your -Path argument and try again."
    throw $_
}

$UProjectFileItem = Get-Item $UProjectInfo._UProjectFile
$UProjectFile = $UProjectFileItem.FullName

Write-Debug "${ScriptName}: Using UProject = $UProjectFile"

$EngineAssociation = $UProjectInfo.EngineAssociation

Write-Debug "${ScriptName}: Searching for UEngine: UProject.EngineAssociation = `"$EngineAssociation`""

$Engine = & UE_GetEngineByAssociation -UProjectFile:$UProjectFile -EngineAssociation:$EngineAssociation

if (!$Engine -or !$Engine.Root) {
    Write-Error "Error determining the Engine directory associated with UProject `"$UProjectFile`", which is associated with Engine `"$EngineAssociation`""
    throw "Invalid Engine Directory `"$($Engine.Root)`""
}

$EngineDir = Join-Path $Engine.Root "Engine"

Write-Debug "${ScriptName}: Using Engine `"$EngineDir`" for UProject `"$UProjectFile`" EngineAssociation `"$EngineAssociation`""

if (!(Test-Path -Path $EngineDir -PathType Container)) {
    throw "Invalid Engine Directory `"$EngineDir`""
}

$EngineConfig = & UE_GetEngineConfig -BuildConfig:$Config -EngineDir:$EngineDir

$uargs = @(
    "-ScriptsForProject=$UProjectFile"
)

$UAT = $EngineConfig.UAT

$Cook = $Cook -or $FullCook;  # -FullCook implies -Cook

if ($Cook -or $Run -or $Stage) {
    $uargs = @(
        "BuildCookRun",
        "-Target=$Target",
        "-Platform=$($EngineConfig.Platform)",
        "-Config=$Config",
        "-Project=$UProjectFile",
        "-UnrealExe=$($EngineConfig.Binaries.EditorCmdName)",
        "-NoP4"
    )

    if ($Build) { $uargs += "-Build" }

    # By default, -Cook is iterative. Use -FullCook to disable iterative cooking.
    if ($Cook) { $uargs += "-Cook"; if (!$FullCook) { $uargs += "-Iterative" } }
    if ($Run) { $uargs += "-Run" }

    # -Stage requires either -Cook or -SkipCook
    if ($Stage) { $uargs += "-Stage"; if (!$Cook) { $uargs += "-SkipCook" } }
}
elseif ($Build) {
    # If all we want to do is -Build, then run UBT instead of UAT
    $UAT = $EngineConfig.UBT

    # Override all previously set $uargs since we're running UBT instead of UAT
    $uargs = @(
        $Target,
        $EngineConfig.Platform,
        $Config
    )
}
else {
    & Usage
}

# Add additional optional pass-thru flags
if ($BuildMachine) { $uargs += "-BuildMachine" }
if ($CrashReporter) { $uargs += "-CrashReporter" }
if ($Distribution) { $uargs += "-Distribution" }
if ($Module) { $uargs += "-Module=$Module" }
if ($Server) { $uargs += "-Server" }

# Run UAT or UBT with args
Write-Debug "${ScriptName}: EXEC: $UAT $uargs"
& $UAT @uargs

# Explicitly exit with the same exit code as UAT/UBT exited with
exit $LASTEXITCODE
