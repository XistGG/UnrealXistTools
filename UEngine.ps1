#
# UEngine.ps1
#
#   Allows you to select an Engine Build based on the Registry.
#
#   -List will show you the list of builds
#   -Help for more info
#
# Epic's Registry Build List:
#   HKEY_CURRENT_USER\Software\Epic Games\Unreal Engine\Builds
#

[CmdletBinding()]
param(
    [switch]$Help,
    [switch]$List,
    [switch]$NoDefault,
    [switch]$Quiet,
    [Parameter()]$UEngineName
)

$UEngineBuildsRegistryKey = "HKEY_CURRENT_USER\Software\Epic Games\Unreal Engine\Builds"


function ListEngineBuildsInRegistry()
{
    param(
        [string]$RegistryKey
    )

    $RegistryBuilds = Get-Item "Registry::$RegistryKey"

    if (!$RegistryBuilds)
    {
        Write-Debug "No Registry Keys Found"
    }
    elseif ($RegistryBuilds.Length -eq 0)
    {
        Write-Debug "Empty Registry Key, no registered Engines found"
    }

    return $RegistryBuilds
}

function WriteHostEngineBuildRegistry()
{
    $EngineBuilds = &ListEngineBuildsInRegistry $UEngineBuildsRegistryKey

    if ($EngineBuilds -and ($EngineBuilds.Length -gt 0))
    {
        Write-Host ""
        Write-Host "Registered Engines ($($EngineBuilds.Length)):"
        Write-Host ""

        for ($i = 0; $i -lt $EngineBuilds.Length; $i++)
        {
            $Property = $EngineBuilds[$i].Property
            $Value = Get-ItemPropertyValue -Path "Registry::$UEngineBuildsRegistryKey" -Name $Property

            Write-Host "  [$i] $Property = '$Value'"
        }

        Write-Host ""
    }
}


function SelectEngineRootByRegistry()
{
    param(
        [switch]$Quiet,
        [switch]$NoDefault,
        [string]$EngineName
    )

    $Result = $null
    $EngineBuilds = &ListEngineBuildsInRegistry $UEngineBuildsRegistryKey

    if ($EngineBuilds -and ($EngineBuilds.Length -gt 0))
    {
        Write-Debug "Registered Engines ($($EngineBuilds.Length)):"

        for ($i = 0; $i -lt $EngineBuilds.Length; $i++)
        {
            $Property = $EngineBuilds[$i].Property
            $Value = Get-ItemPropertyValue -Path "Registry::$UEngineBuildsRegistryKey" -Name $Property

            Write-Debug "  [$i] $Property = '$Value'"

            if ($EngineName -and ($Property -ieq $EngineName))
            {
                # An explicit $EngineName search matched
                $Result = @{Name=$Property; Root=$Value}

                Write-Debug "$Property matches -Engine; select result [$i]"
            }
            elseif (!$EngineName -and ($EngineBuilds.Length -eq 1) -and !$NoDefault)
            {
                # - There is no explicit $EngineName Search
                # - There is exactly 1 registered Engine Build
                # - The -NoDefault switch is not set

                # Select this, the only registered Engine Build, as the default result
                $Result = @{Name=$Property; Root=$Value}

                Write-Debug "$Property matches -Engine; select result [$i]"
            }
        }
    }

    return $Result
}


# Get/Set the current $UEngine

$UEngine = &SelectEngineRootByRegistry -EngineName:$UEngineName -NoDefault:$NoDefault -Quiet:$Quiet

if ($UEngine)
{
    $UEngineName = $UEngine.Name
    $UEngineDirectory = Get-Item -Path $UEngine.Root
}
else
{
    # $UEngineName is invalid; leave it as its invalid value
    $UEngineDirectory = $null
}

if ($List)
{
    &WriteHostEngineBuildRegistry
}

if ($UEngine)
{
    if (!$Quiet)
    {
        Write-Host "UEngineName=$UEngineName"
        Write-Host "UEngineDirectory=$UEngineDirectory"
    }
}
elseif ($UEngineName)
{
    # User asked for a specific name that does not exist
    Write-Error "No Such Engine Name: $UEngineName"
}
else
{
    Write-Host "No UEngine is selected."

    Write-Host "Use the -List switch to see the list of all registered Engines."
    Write-Host "Use the -Engine parameter to specify one of the registered names."
}

if ($Help)
{
    $ScriptName = $MyInvocation.MyCommand.Name
    Write-Host @"

############################################################
##
##  Usage for ${ScriptName}:
##

& $ScriptName -List

    Display a list of currently registered engines

& $ScriptName EngineName

    Select the EngineName engine

& $ScriptName -NoDefault

    Explicitly disable use of a default EngineName.
    Mainly useful for debugging.

"@
}
