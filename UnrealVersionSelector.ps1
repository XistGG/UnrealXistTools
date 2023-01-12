#
# UnrealVersionSelector.ps1
#
# See: https://github.com/XistGG/UnrealXistTools/
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
    Write-Warning "Exit Code $e"
}
else
{
    Write-Host "Exit Code $e"
}

Write-Host ""
exit $e
