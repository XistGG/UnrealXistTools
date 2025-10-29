#!/usr/bin/env pwsh
#
# UEdit.ps1
#
# Open a UProject in Unreal Editor Development mode
#

[CmdletBinding()]
param(
    [Parameter()]$Path
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

# Import the UE helper module
Import-Module -Name $PSScriptRoot/Modules/UE.psm1

################################################################################
##  Main
################################################################################

# Require a valid $UProjectFile

Write-Debug "Compute UProjectFile Path=[$Path]"

# Determine which UProjectFile we will Edit
$UProject =& $PSScriptRoot/UProject.ps1 -Path:$Path

if (!$UProject)
{
    throw "Path is not a UProject: $Path"
}

$UProjectFile = Get-Item -Path $UProject._UProjectFile

try
{
    $UEngine =& UE_GetEngineByAssociation -UProjectFile $UProjectFile.FullName -EngineAssociation $UProject.EngineAssociation

	if ($UEngine -and $UEngine.Root)
	{
	    # If it didn't, regenerate project files.
    	$UEngineConfig =& UE_GetEngineConfig -EngineRoot $UEngine.Root

		# Open the UProject in UEditor
		Write-Debug "EXEC: $($UEngineConfig.Binaries.Editor) $($UProjectFile.FullName)"
		& $UEngineConfig.Binaries.Editor $UProjectFile.FullName
		exit $LASTEXITCODE
	}
}
catch
{
	Write-Warning "Unable to find associated Engine, will try UnrealVersionSelector as a backup"
}


# Start UVS -Editor on the selected UProjectFile

& $PSScriptRoot/UnrealVersionSelector.ps1 -Editor $UProjectFile.FullName
exit $LASTEXITCODE
