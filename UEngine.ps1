#
# UEngine.ps1
#
#   UEngine.ps1 allows you to select an Engine Build based on the Registry.
#   If you have only 1 custom engine, it uses that as the default.  Otherwise
#   you can select different engines based on their names.
#
#   -List will show you the list of builds
#   -Help for more info
#
# Epic's Registry Build List:
#   HKEY_CURRENT_USER\Software\Epic Games\Unreal Engine\Builds
#

[CmdletBinding()]
param(
    [Parameter()]$Name,
    [switch]$Help,
    [switch]$List,
    [switch]$NoDefault
)

$BuildsRegistryKey = "HKEY_CURRENT_USER\Software\Epic Games\Unreal Engine\Builds"


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

& $ScriptName Name

    Select the Name engine

& $ScriptName -NoDefault

    Explicitly disable use of a default Name.
    Mainly useful for debugging.

"@
    return $null
}


# Read $BuildsRegistryKey to discover the list of Engine Builds
# @return $null, or the Registry Item if found
#
function ListEngineBuildsInRegistry()
{
    $RegistryBuilds = Get-Item "Registry::$BuildsRegistryKey" 2> $null

    if (!$RegistryBuilds)
    {
        Write-Warning "Build Registry Not Found: $BuildsRegistryKey"
    }
    elseif ($RegistryBuilds.Length -eq 0)
    {
        Write-Debug "Empty Registry Key, no registered Engines found"
    }

    return $RegistryBuilds
}


# Write-Host the current contents of $BuildsRegistryKey
#
function ListHostEngineBuildRegistry()
{
    $Result = @()
    $EngineBuilds = &ListEngineBuildsInRegistry

    if ($EngineBuilds -and ($EngineBuilds.Length -gt 0))
    {
        for ($i = 0; $i -lt $EngineBuilds.Length; $i++)
        {
            $Property = $EngineBuilds[$i].Property
            $Value = Get-ItemPropertyValue -Path "Registry::$BuildsRegistryKey" -Name $Property

            $Result += @{Name=$Property; Root=$Value}
        }
    }

    return $Result
}


function SelectEngineRootByRegistry()
{
    $Result = $null
    $EngineBuilds = &ListEngineBuildsInRegistry

    if ($EngineBuilds -and ($EngineBuilds.Length -gt 0))
    {
        Write-Debug "Registered Engines ($($EngineBuilds.Length)):"

        for ($i = 0; $i -lt $EngineBuilds.Length; $i++)
        {
            $Property = $EngineBuilds[$i].Property
            $Value = Get-ItemPropertyValue -Path "Registry::$BuildsRegistryKey" -Name $Property

            Write-Debug "  [$i] $Property = '$Value'"

            if ($Name -and ($Property -ieq $Name))
            {
                # An explicit $Name search matched
                $Result = @{Name=$Property; Root=$Value}

                Write-Debug "$Property matches -Engine; select result [$i]"
            }
            elseif (!$Name -and ($EngineBuilds.Length -eq 1))
            {
                # - There is no explicit $Name Search
                # - There is exactly 1 registered Engine Build

                if ($NoDefault)
                {
                    # - The -NoDefault switch is set
                    Write-Debug "$Property is only Engine but -NoDefault is set; DO NOT use as default"
                }
                else
                {
                    # - The -NoDefault switch is not set
                    # Select this, the only registered Engine Build, as the default result
                    $Result = @{Name=$Property; Root=$Value}

                    Write-Debug "$Property is the only engine, use as default result [$i]"
                }
            }
        }
    }

    return $Result
}


# If they didn't supply a specific Engine Name, choose a default Engine if !$NoDefault
if (!$Name -and !$NoDefault)
{
    # Select default UProject
    $UProject = & $PSScriptRoot/UProject.ps1

    if ($UProject)
    {
        $Name = $UProject.EngineAssociation

        Write-Debug "Using '$Name' Engine Name for UProject: $UProjectFile"
    }
}


# If they just want to see a list, show it
if ($List)
{
    $BuildList = &ListHostEngineBuildRegistry
    return $BuildList
}


# Get/Set the current $UEngine

$UEngine = &SelectEngineRootByRegistry

if ($UEngine)
{
    Write-Debug "UEngine = $($UEngine.Name) = $($UEngine.Root)"
}
elseif ($Name)
{
    # User asked for a specific name that does not exist
    Write-Error "No Such Engine Name: $Name"
}
else
{
    Write-Host ""
    Write-Host "No UEngine is selected."
    Write-Host ""

    # Execute own help and exit
    return & $PSScriptRoot/UEngine.ps1 -Help
}

return $UEngine
