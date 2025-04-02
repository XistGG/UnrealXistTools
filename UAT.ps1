#!/usr/bin/env pwsh
#
# UAT.ps1
#

[CmdletBinding()]
param(
    [string]$Config = "Development",
    [string]$Target = "LyraGameEOS",
    [switch]$Cook,
    [switch]$Build,
    [switch]$Run,
    [switch]$Server,
    [switch]$Stage,
    [switch]$FullCook,
    [switch]$Help,
    [Parameter(Position = 0)]$Path
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

Usage: $ScriptName [-Path UProject] [-Config DebugGame] [-Target LyraGameSteam] -Build
       $ScriptName [-Path UProject] [-Config DebugGame] [-Target LyraGameSteam] -Cook
       $ScriptName [-Path UProject] [-Config DebugGame] [-Target LyraGameSteam] -Stage
       $ScriptName [-Path UProject] [-Config DebugGame] [-Target LyraGameSteam] -Run
       $ScriptName -Help

    -Build       Build the project. Required before you can Cook.
    -Cook        Cook the project so you can run the Game independently of the Editor.
                 By default this will cook incrementally for faster execution.
    -FullCook    If you pass -FullCook then we won't do an incremental cook, and instead
                 will fully cook from scratch (takes longer).
    -Stage       Stage the project (after cooking) in preparation for packaging.
    -Run         Run the Target.

    -Config      The build configuration ("Development", "DebugGame", "Shipping", etc)
    -Target      The build target (prefix of your "*.Target.cs" file)

    -Help        Print this Usage info and exit.

    [-Debug]     If present, prints additional debugging information.
    [-Path]      (Optional) Path to your ".uproject" file/directory.
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

try
{
    # Convert the -Path param (if any) to a $UProjectInfo object
    $UProjectInfo =& $PSScriptRoot\UProject.ps1 -Path:$Path
}
catch
{
    Write-Error "Unable to read the UProject file at -Path `"$Path`", check your -Path argument and try again."
    throw $_
}

$UProjectFileItem = Get-Item $UProjectInfo._UProjectFile
$UProjectFile = $UProjectFileItem.FullName

Write-Debug "${ScriptName}: Using UProject = $UProjectFile"

$EngineAssociation = $UProjectInfo.EngineAssociation

Write-Debug "${ScriptName}: Searching for UEngine: UProject.EngineAssociation = `"$EngineAssociation`""

$Engine =& UE_GetEngineByAssociation -UProjectFile:$UProjectFile -EngineAssociation:$EngineAssociation

if (!$Engine -or !$Engine.Root)
{
    Write-Error "Error determining the Engine directory associated with UProject `"$UProjectFile`", which is associated with Engine `"$EngineAssociation`""
    throw "Invalid Engine Directory `"$($Engine.Root)`""
}

$EngineDir = Join-Path $Engine.Root "Engine"

Write-Debug "${ScriptName}: Using Engine `"$EngineDir`" for UProject `"$UProjectFile`" EngineAssociation `"$EngineAssociation`""

if (!(Test-Path -Path $EngineDir -PathType Container))
{
    throw "Invalid Engine Directory `"$EngineDir`""
}

$EngineConfig =& UE_GetEngineConfig -BuildConfig:$Config -EngineDir:$EngineDir

$args = @(
    "-ScriptsForProject=$UProjectFile"
    )

$UAT = $EngineConfig.UAT

$Cook = $Cook -or $FullCook;  # -FullCook implies -Cook

if ($Cook -or $Run -or $Stage)
{
    $args = @(
        "BuildCookRun",
        "-Target=$Target",
        "-Platform=$($EngineConfig.Platform)",
        "-Config=$Config",
        "-Project=$UProjectFile",
        "-UnrealExe=$($EngineConfig.Binaries.EditorCmdName)",
        "-NoP4"
        )

    if ($Build)        { $args += "-Build" }
    if ($Server)       { $args += "-Server" }

    # By default, -Cook is iterative. Use -FullCook to disable iterative cooking.
    if ($Cook)         { $args += "-Cook";    if (!$FullCook) { $args += "-Iterative" } }
    if ($Run)          { $args += "-Run" }

    # -Stage requires either -Cook or -SkipCook
    if ($Stage)        { $args += "-Stage";   if (!$Cook) { $args += "-SkipCook" } }
}
elseif ($Build)
{
    # If all we want to do is -Build, then run UBT instead of UAT
    $UAT = $EngineConfig.UBT

    # Override all previously set $args since we're running UBT instead of UAT
    $args = @(
        $Target,
        $EngineConfig.Platform,
        $Config
        )
}
else
{
    & Usage
}

Write-Debug "${ScriptName}: EXEC: $UAT $($args -join ' ')"

& $UAT @args

# Explicitly exit with the same exit code as UAT/UBT exited with
exit $LASTEXITCODE
