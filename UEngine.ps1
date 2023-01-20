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
    [Parameter()]$UProject,
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

    Return a list of currently registered engines as objects like:
    {Name="foo", Root="C:\Root\"}

& $ScriptName Name

    Return the Named engine build, returns null if no such Name.

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
    $Result = @()

    if (!$RegistryBuilds)
    {
        Write-Warning "Build Registry Not Found: $BuildsRegistryKey"
    }
    else
    {
        for ($i = 0; $i -lt $RegistryBuilds.Length; $i++)
        {
            $Property = $RegistryBuilds[$i].Property
            if ($Property)
            {
                # This is a non-empty $Property value, so it's a registered engine build

                # Get the ItemPropertyValue for this $Property
                $Value = Get-ItemPropertyValue -Path "Registry::$BuildsRegistryKey" -Name $Property

                # Add this registered build to the output result
                $Result += @{Name=$Property; Root=$Value}
            }
            else
            {
                Write-Debug "Skip empty property for RegistryBuilds[$i]"
            }
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

            # Sometimes the key exists but does not actually contain any properties,
            # in which case there aren't any engine builds registered
            if (!$Property)
            {
                Write-Debug "Registry key contains empty property at i=$i, ignoring it"
                continue;
            }

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


################################################################################
##  Main
################################################################################


# If they just want to see a list, show it
if ($List)
{
    $BuildList = &ListEngineBuildsInRegistry
    if ($BuildList -and $BuildList.Count -gt 0)
    {
        return $BuildList
    }
    return $null
}


################################################################################
##  Resolve Project


# If $UProject is set, resolve it
if ($UProject)
{
    $UProject = & $PSScriptRoot/UProject.ps1 -Path:$UProject
}


# If they didn't supply a specific Engine Name, choose a default Engine if !$NoDefault
if (!$Name -and !$NoDefault)
{
    if (!$UProject)
    {
        # No $UProject was named, so load the default UProject
        $UProject = & $PSScriptRoot/UProject.ps1
    }

    if ($UProject)
    {
        $Name = $UProject.EngineAssociation

        Write-Debug "Using '$Name' Engine Name for UProject: $UProjectFile"
    }
}


################################################################################
##  Get/Set the current $UEngine


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
    # User asked for no name in particular, and no default is in effect,
    # so there is no $UEngine selected.

    # Execute own help
    & $PSScriptRoot/UEngine.ps1 -Help

    return $null
}

return $UEngine
