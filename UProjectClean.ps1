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
#   - Remove *.sln files from the project root
#   - Generate Project Files
#

[CmdletBinding()]
param(
    [switch]$DryRun,
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
$TempDirs = Get-ChildItem -Path $UProjectDirectory -Recurse `
    | Where-Object {$_.PSIsContainer `
        -and (($_.Name -ieq 'Binaries') `
          -or ($_.Name -ieq 'Intermediate') `
          -or (($_.Name -ieq 'DerivedDataCache') -and $ResetDDC) `
        ) `
      }

# *.sln files in the root folder
$TempFiles = Get-ChildItem -Path $UProjectDirectory `
    | Where-Object {!$_.PSIsContainer -and ($_.Extension -ieq '.sln')}


################################################################################
###  DELETE Binaries + Intermediate + other temporary files
################################################################################

# If there is stuff to delete, then delete it
if (($TempDirs.count + $TempFiles.count) -gt 0)
{
    Write-Host "Deleting generated data..."

    foreach ($TempDir in $TempDirs)
    {
        Write-Host "[-] $TempDir"
        if (!$DryRun)
        {
            Remove-Item -Force -Recurse $TempDir
        }
    }

    foreach ($TempFile in $TempFiles)
    {
        Write-Host "[-] $TempFile"
        if (!$DryRun)
        {
            Remove-Item -Force $TempFile
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
