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
# @return ArrayList with each element being like @{ Name="EngineName"; Root="C:\Root" }
#
function ListEngineBuildsInRegistry()
{
    $RegistryBuilds = Get-Item -Path "Registry::$BuildsRegistryKey" 2> $null
    $Result = [System.Collections.ArrayList]@()

    if (!$RegistryBuilds)
    {
        Write-Warning "Build Registry Not Found: $BuildsRegistryKey"
    }
    else
    {
        # Must iterate to Length; registry key does not have a Count
        for ($i = 0; $i -lt $RegistryBuilds.Length; $i++)
        {
            $PropertyList = $RegistryBuilds[$i].Property

            # PropertyList is an actual array, it has a Count
            if ($PropertyList -and $PropertyList.Count -gt 0)
            {
                for ($p = 0; $p -lt $PropertyList.Count; $p++)
                {
                    $BuildName = $PropertyList[$p]

                    if ($BuildName)
                    {
                        # Get the ItemPropertyValue for this $BuildName
                        $Value = Get-ItemPropertyValue -Path "Registry::$BuildsRegistryKey" -Name $BuildName

                        # Create a Build object
                        $Build = [pscustomobject]@{ Name=$BuildName; Root=$Value }

                        Write-Debug "Read Engine[$($Result.Count)] [$BuildName] = [$Value]"

                        # Append the build to the $Result array
                        $Result += $Build
                    }
                    else
                    {
                        Write-Debug "Skip empty BuildName for RegistryBuilds[$i].Property[$p]"
                    }
                }
            }
            else
            {
                Write-Debug "Skip empty PropertyList for RegistryBuilds[$i]"
            }
        }
    }

    return $Result
}


function SelectEngineRootByRegistry()
{
    $Result = $null
    $EngineBuilds = &ListEngineBuildsInRegistry

    if ($EngineBuilds -and $EngineBuilds.Count -gt 0)
    {
        Write-Debug "Registered Engines ($($EngineBuilds.Count)):"

        for ($i = 0; $i -lt $EngineBuilds.Count; $i++)
        {
            $Build = $EngineBuilds[$i]

            Write-Debug "  [$i] $($Build.Name) = '$($Build.Root)'"

            # If searching for a specific $Name and it matches this $Build.Name
            if ($Name -and ($Build.Name -ieq $Name))
            {
                # An explicit $Name search matched
                $Result = $Build

                Write-Debug "Name search match [$Name]; select result [$i]"
            }
            elseif (!$Name -and ($EngineBuilds.Count -eq 1))
            {
                # - There is no explicit $Name Search
                # - There is exactly 1 registered Engine Build

                if ($NoDefault)
                {
                    # - The -NoDefault switch is set
                    Write-Debug "$($Build.Name) is the only Engine but -NoDefault is set; DO NOT use as default"
                }
                else
                {
                    # - The -NoDefault switch is not set
                    # Select this, the only registered Engine Build, as the default result
                    $Result = $Build

                    Write-Debug "$($Build.Name) is the only engine, use as default result [$i]"
                }
            }
        }

        # If we did not find a suitable result, and an explicit search $Name is not set
        if (!$Result -and !$Name)
        {
            if (!$NoDefault)
            {
                if ($EngineBuilds.Count -eq 1)
                {
                    # There is only 1 custom engine; That is the default
                    $Result = $EngineBuilds[0]
                }
                else
                {
                    # Check current directory (and recursively its parents)
                    # to see if any of them are a registered Engine, and if so
                    # select the engine whose directory tree we are in.

                    $d = Get-Item -Path $(Get-Location)

                    while ($d -and !$Result)
                    {
                        for ($i = 0; $i -lt $EngineBuilds.Count; $i++)
                        {
                            # Discard stderr as sometimes this path won't exist, that's fine, don't confuse people with errors to the console
                            $root = Get-Item -Path $EngineBuilds[$i].Root 2> $null

                            # Check if it exists
                            if ($root -and ($root.FullName -ieq $d.FullName))
                            {
                                # Found this Build root
                                $Result = $EngineBuilds[$i]

                                Write-Debug "Found Engine[$i].Root: $root"

                                # Don't need to keep searching
                                break
                            }
                            elseif (!$root)
                            {
                                Write-Debug "Engine[$i].Root [$($EngineBuilds[$i].Root)] root does not exist [$($EngineBuilds[$i].Root)]"
                            }
                            else
                            {
                                Write-Debug "Engine[$i].Root [$($EngineBuilds[$i].Root)] not match [$d]"
                            }
                        }

                        # Traverse up until there is no more traversing
                        $d = $d.Parent
                    }
                }
            }
            else
            {
                Write-Debug "Build is not set; not choosing default build due to -NoDefault"
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
    return $BuildList
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
        try
        {
            # No $UProject was named, so load the default UProject
            # We don't care about errors here, if there is no active project, that's fine
            $UProject = & $PSScriptRoot/UProject.ps1 2> $null
        }
        catch
        {
            $UProject = $null
            Write-Debug "Not in an active UProject directory, cannot auto-select Engine"
        }
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
