#
# UnrealVersionSelector.ps1
#
# Usage:
#
#   UnrealVersionSelector.ps1
#     - Regenerate Project Files for project named
#       the same as the current directory
#
#   UnrealVersionSelector.ps1 MyGame.uproject
#     - Regenerate Project Files for project MyGame.uproject
#

[CmdletBinding()]
param(
    [switch]$ProjectFiles,
    [switch]$SwitchVersionSilent,
    [switch]$Quiet,
    [Parameter()] $UProjectFile,
    [Parameter(ValueFromRemainingArguments=$true)] $VarArgs
)


################################################################################
###  Find UnrealVersionSelector.exe on this host
################################################################################

# defer to Environment if var is set
$UnrealVersionSelector = $env:UnrealVersionSelector

# a list of common locations to scan supporting multiple platforms
# TODO add Mac & Linux support
$DEFAULTS = @(
    'C:\Program Files (x86)\Epic Games\Launcher\Engine\Binaries\Win64\UnrealVersionSelector.exe',
    'C:\Program Files\Epic Games\Launcher\Engine\Binaries\Win32\UnrealVersionSelector.exe'
)


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


if (!(&IsUnrealVersionSelectorValid $UnrealVersionSelector))
{
    $UnrealVersionSelector = $null

    foreach ($Path in $DEFAULTS)
    {
        if (&IsUnrealVersionSelectorValid $Path)
        {
            $UnrealVersionSelector = $Path
            break
        }
    }

    if ($UnrealVersionSelector -eq $null)
    {
        Write-Error "UnrealVersionSelector NOT FOUND! You must set the UnrealVersionSelector environment variable"
        exit 1
    }
}


################################################################################
###  Expand $UProjectFile argument into absolute path of a UProject
################################################################################

# If user didn't specify a project file, default to current directory
if ((!$PSBoundParameters.ContainsKey('UProjectFile')) -or ($UProjectFile -eq ''))
{
    $UProjectFile = '.'
}
. $PSScriptRoot\UProjectFile.ps1


################################################################################
###  Run Unreal Version Selector
################################################################################

$e = 0;

Write-Host ""

if ($SwitchVersionSilent)
{
    Write-Host "EXEC: $UnrealVersionSelector -switchversionsilent $UProjectFile ${VarArgs[0]}"
    $process = Start-Process -Wait -PassThru -FilePath $UnrealVersionSelector -ArgumentList "-switchversionsilent",$UProjectFile,$VarArgs[0]
    $e = $process.ExitCode
}
elseif ($ProjectFiles)
{
    Write-Host "EXEC: $UnrealVersionSelector -projectfiles $UProjectFile"
    $process = Start-Process -Wait -PassThru -FilePath $UnrealVersionSelector -ArgumentList "-projectfiles",$UProjectFile
    $e = $process.ExitCode
}
else
{
    Write-Host "Use -projectfiles to regenerate project files"
    Write-Host ""
    exit 0
}


if ($e -ne 0)
{
    Write-Warning "UnrealVersionSelector exited with code $e"
}
else
{
    Write-Host "Exit Code $e"
}

Write-Host ""
exit $e
