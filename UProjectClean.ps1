#!/usr/bin/env pwsh
#
# UProjectClean.ps1
#
# See: https://github.com/XistGG/UnrealXistTools/
#
# Clean an Unreal Project
#
#   - Remove Binaries dirs
#   - Remove Intermediate dirs
#   - Remove DerivedDataCache dirs (only if -DDC switch or -Nuke)
#   - Remove Saved dir (only if -Saved switch or -Nuke)
#   - Remove .idea directories (only if -Idea switch or -Nuke)
#   - Remove *.sln files from the project root
#   - Generate Project Files
#

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Idea,
    [switch]$DDC,
    [switch]$Nuke,
    [switch]$Saved,
    [Parameter()]$Path
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

# Import the UE helper module
Import-Module -Name $PSScriptRoot/Modules/UE.psm1

# Determine which UProjectFile we will clean
$UProject =& $PSScriptRoot/UProject.ps1 -Path:$Path

if (!$UProject)
{
    throw "No .uproject selected for clean"
}

$UProjectFile = Get-Item -Path $UProject._UProjectFile

# If the -Nuke switch is set, then explicitly set all the optional deletion flags
if ($Nuke)
{
    $DDC = $true;
    $Idea = $true;
    $Saved = $true;
}


################################################################################
###  Find Binaries + Intermediate + other temporary files
################################################################################

# Make sure we're in the project directory before doing file operations
Push-Location $UProjectFile.Directory

Write-Host "Scanning files & directories..."

# All directories at any depth named 'Binaries' or 'Intermediate'
# Include DerivedDataCache directories only if you set -DDC parameter
#
$TempDirs = Get-ChildItem -Path $UProjectFile.Directory -Directory -Recurse `
    | Where-Object { `
              ($_.Name -ieq 'Binaries') `
          -or ($_.Name -ieq 'Intermediate') `
          -or (($_.Name -ieq 'DerivedDataCache') -and $DDC) `
          -or (($_.Name -ieq '.idea') -and $Idea) `
      }

# Only nuke the Saved folder in the root uproject directory
# if the -Saved switch is explicitly set
if ($Saved)
{
    $TempDirs += Get-ChildItem -Path $UProjectFile.Directory -Directory `
        | Where-Object {$_.Name -ieq 'Saved'}
}

# *.sln files in the root folder
$TempFiles = Get-ChildItem -Path $UProjectFile.Directory -File `
    | Where-Object {$_.Extension -ieq '.sln'}


Write-Host ""
################################################################################
###  DELETE Binaries + Intermediate + other temporary files
################################################################################

# If there is stuff to delete, then delete it
if (($TempDirs.count + $TempFiles.count) -gt 0)
{
    Write-Host "Deleting generated data..."

    foreach ($TempDir in $TempDirs)
    {
        # If the temp dir still exists, delete it
        # (handles nested paths that were previously deleted this run)
        if (Test-Path -Path $TempDir.FullName)
        {
            Write-Host "[-] $TempDir"

            if (!$DryRun)
            {
                Remove-Item -Force -Recurse -Path $TempDir.FullName
            }
        }
    }

    foreach ($TempFile in $TempFiles)
    {
        # If the temp file still exists, delete it
        # (handles nested paths that were previously deleted this run)
        if (Test-Path -Path $TempFile.FullName)
        {
            Write-Host "[-] $TempFile"

            if (!$DryRun)
            {
                Remove-Item -Force -Path $TempFile.FullName
            }
        }
    }

    Write-Host ""
}


################################################################################
###  Generate Project Files
################################################################################

try
{
    if ($DryRun)
    {
        Write-Warning "Exiting without generating project files due to -DryRun"
        exit 151
    }

    # Look up the UEngine associated with this .uproject, if possible
    #
	# Note that UE_GetEngineByAssociation doesn't know how to find Launcher-installed engines
    # on Linux/Mac platforms.
	#
    # It can only find custom compiled engines, so it may throw an exception.

	try
	{
	    $UEngine =& UE_GetEngineByAssociation -UProjectFile $UProjectFile.FullName -EngineAssociation $UProject.EngineAssociation

		if ($UEngine -and $UEngine.Root)
		{
		    # If it didn't, regenerate project files.
    		$UEngineConfig =& UE_GetEngineConfig -EngineRoot $UEngine.Root

		    # Execute the engine's GenerateProjectFiles.sh
		    if ($UEngineConfig -and (Test-Path -Path $UEngineConfig.GenerateProjectFiles))
		    {
	    		& $UEngineConfig.GenerateProjectFiles
		    	exit $LASTEXITCODE
		    }
		}
	}
	catch
	{
		Write-Warning "Unable to find GenerateProjectFiles on this system"
	}

    if ($IsWindows)
    {
    	# We will try to fall back to the default launcher UVS if possible
		Write-Host "Trying to generate project files with Launcher-installed UnrealVersionSelector (if any)..."

        # UnrealVersionSelector.ps1 only works on Windows, so we'll use it.
        # The advantage here is this works with Launcher-installed engines as well as custom engines.
        . $PSScriptRoot\UnrealVersionSelector.ps1 -ProjectFiles $UProjectFile.FullName
        # NOTICE: UnrealVersionSelector.ps1 calls exit()
    }
    else
    {
        # Epic's UnrealVersionSelector does not work on Linux/Mac.

		throw "Unable to Generate Project Files"
    }
}
finally
{
    # Ensure the calling PowerShell session is in the same directory after running this script
    # as it was when it started running this script
    Pop-Location
}
