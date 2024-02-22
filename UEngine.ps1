#!/usr/bin/env pwsh
#
# UEngine.ps1
#
#   UEngine.ps1 allows you to select an Engine Build based on the Registry.
#   If you have only 1 custom engine, it uses that as the default.  Otherwise
#   you can select different engines based on their names.
#
#   -List will show you the list of builds
#   -NewName will allow you to rename the registry keys
#   -Help for more info
#
# Epic's Registry Build List:
#   HKEY_CURRENT_USER\Software\Epic Games\Unreal Engine\Builds
#

[CmdletBinding()]
param(
    [Parameter()]$Name,
    [Parameter()]$NewName,
    [Parameter()]$UProject,
    [switch]$Help,
    [switch]$List,
    [switch]$NoDefault,
    [switch]$Start
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

# Import the UE helper module
Import-Module -Name $PSScriptRoot/Modules/UE.psm1

$BuildsRegistryKey = "HKEY_CURRENT_USER\Software\Epic Games\Unreal Engine\Builds"

# TODO this only works on Win64! Need to upgrade this for other dev platforms
$PlatformSpecificEditorPath = "Engine/Binaries/Win64/UnrealEditor.exe"


function Usage
{
    $ScriptName = $MyInvocation.MyCommand.Name
    Write-Host @"

############################################################
##
##  Usage for ${ScriptName}:
##

& $ScriptName -Debug

    Use the -Debug flag at any time to see more detailed debug info.

& $ScriptName -List

    Return a list of currently registered engines as objects like:
    {Name="foo", Root="C:\Root\"}

& $ScriptName Name

    Return the Named engine, returns null if no such Name.

& $ScriptName Name -NewName MyEngine

    Change the name of the "Name" engine to "MyEngine".
    Return the build with the updated name.

    Note that for random GUID names, you need to enclose it in quotes, like:
    $ScriptName "{Random-GUID-here}" -NewName MyEngine

& $ScriptName -NoDefault

    Explicitly disable use of a default Name.
    Mainly useful for debugging.

"@
    exit 1
}

if ($Help)
{
    & Usage
}


################################################################################
##  Main
################################################################################


# If they just want to see a list, show it
if ($List)
{
    $BuildList =& UE_ListCustomEngines
    if (!$BuildList.Count)
    {
        Write-Error ("There are no custom Unreal Engine Builds in the Registry. " +
            "You need to run UnrealVersionSelector.exe in your Custom Engine Directory. " +
            "Example: D:/UE_5.1/Engine/Binaries/Win64/UnrealVersionSelector-Win64-Shipping.exe")
    }
    return $BuildList
}


################################################################################
##  Resolve Project


# If $UProject is set, resolve it
if ($UProject)
{
    Write-Debug "Loading explicitly named UProject `"$UProject`""
    $UProject =& $PSScriptRoot/UProject.ps1 -Path:$UProject
}


# If they didn't supply an explicit name, but they did supply a $UProject,
# then use the EngineAssociation from the $UProject
if (!$Name)
{
    if (!$UProject)
    {
        try
        {
            # No $UProject was named, so load the default UProject
            # We don't care about errors here, if there is no active project, that's fine
            Write-Debug "Loading implicitly active UProject based on current directory"
            $UProject =& $PSScriptRoot/UProject.ps1 2> $null
        }
        catch
        {
            $UProject = $null
            Write-Debug "Not in an active UProject directory, cannot auto-select Engine by UProject"
        }
    }

    if (!$UProject)
    {
        Write-Error "No -Name provided and no UProject found in the current directory `"$(Get-Location)`""
        throw "Invalid Usage. See -Help for more info."
   }

    $Name = $UProject.EngineAssociation  # Might be ""
    Write-Debug "Loading Engine based on UProject `"$($UProject._UProjectFile)`" EngineAssociation `"$Name`""
    $UEngine =& UE_GetEngineByAssociation -UProjectFile $UProject._UProjectFile -EngineAssociation $UProject.EngineAssociation

    if ($UEngine)
    {
        # In case the UProject.EngineAssociation was "", get the real name of the UEngine we loaded
        $Name = $UEngine.Name
    }
}
else
{
    Write-Debug "Loading Engine based on explicit name `"$Name`""
    $UEngine =& UE_SelectCustomEngine -Name $Name
}


################################################################################
##  Get/Set the current $UEngine


if ($UEngine)
{
    Write-Debug "Selected UEngine: $($UEngine.Name) = $($UEngine.Root)"

    # If they want to change the name, do so
    if ($NewName)
    {
        Write-Debug "Renaming Engine `"$($UEngine.Name)`" to `"$NewName`""
        # Try to change the name and reload the engine from the new name
        $UEngine =& UE_RenameCustomEngine -OldName $UEngine.Name -NewName $NewName
    }
}
elseif ($Name)
{
    # User asked for a specific name that does not exist
    Write-Error "No Such Engine Name: $Name"
}

return $UEngine
