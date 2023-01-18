#
# UnrealProjectClean.ps1
#
# See: https://github.com/XistGG/UnrealXistTools/
#
# Clean an Unreal Project
#
#   - Remove Binaries dirs
#   - Remove Intermediate dirs
#   - Remove DerivedDataCache dirs (only if -ResetDDC switch)
#   - Remove .idea directories (only if -Idea switch)
#   - Remove *.sln files from the project root
#   - Generate Project Files
#

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Idea,
    [switch]$ResetDDC,
    [Parameter()] $UProjectFile
)


# Resolve optional $UProjectFile parameter
# (throw if no valid $UProjectFile)
#   - Set $UProjectFile
#   - Set $UProjectDirectory
#
. $PSScriptRoot\UProjectFile.ps1


################################################################################
###  Find Binaries + Intermediate + other temporary files
################################################################################

Write-Host "Scanning files & directories..."

# All directories at any depth named 'Binaries' or 'Intermediate'
# Include DerivedDataCache directories only if you set -ResetDDC parameter
#
$TempDirs = Get-ChildItem -Path $UProjectDirectory -Directory -Recurse `
    | Where-Object { `
              ($_.Name -ieq 'Binaries') `
          -or ($_.Name -ieq 'Intermediate') `
          -or (($_.Name -ieq 'DerivedDataCache') -and $ResetDDC) `
          -or (($_.Name -ieq '.idea') -and $Idea) `
      }

# *.sln files in the root folder
$TempFiles = Get-ChildItem -Path $UProjectDirectory -File `
    | Where-Object {$_.Extension -ieq '.sln'}


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

if ($DryRun)
{
    Write-Warning "Exiting without generating project files due to -DryRun"
    exit 151
}

. $PSScriptRoot\UnrealVersionSelector.ps1 -quiet -projectfiles $UProjectFile
