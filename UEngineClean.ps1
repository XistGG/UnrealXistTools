#
# UnrealEngineClean.ps1
#
# See: https://github.com/XistGG/UnrealXistTools/
#
# Clean an Unreal Engine
#
#   - Remove Binaries dirs
#   - Remove Intermediate dirs
#   - Remove DerivedDataCache dirs (only if -DDC switch)
#   - Remove *.sln files from the project root
#   - Generate Project Files
#

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$DDC,
    [Parameter()]$Path
)

# Clean the engine in the current directory by default
if (!$Path)
{
    $Path = Get-Location
}

$PathItem = Get-Item $Path
if (!$PathItem -or !$PathItem.Exists -or !$PathItem.PSIsContainer)
{
    throw "Invalid Path [$Path]; must be an existing directory"
}
$Path = $PathItem.FullName

# Make sure there is an "Engine" dir in the $Path dir

$EngineDirItem = Get-Item "$Path/Engine"
if (!$EngineDirItem -or !$EngineDirItem.PSIsContainer)
{
    throw "Invalid Engine Dir [$Path]"
}
$EngineDir = $EngineDirItem.FullName


################################################################################
###  Find Binaries + Intermediate + other temporary files
################################################################################

Write-Host "Scanning files & directories..."

$TempDirs = Get-ChildItem -Path $EngineDir -Directory `
    | Where-Object { `
              ($_.Name -ieq 'Binaries') `
          -or ($_.Name -ieq 'Intermediate') `
          -or (($_.Name -ieq 'DerivedDataCache') -and $DDC) `
      }


$EngineDirs = ("Extras", "Plugins", "Programs", "Shaders")

foreach ($Dir in $EngineDirs)
{
    Write-Debug "Scan Engine Dir: $Dir"
    $TempDirs += Get-ChildItem -Path "$EngineDir/$Dir" -Directory -Recurse `
        | Where-Object { `
                  ($_.Name -ieq 'Binaries') `
              -or ($_.Name -ieq 'Intermediate') `
          }
}


$EngineSourceDirItems = Get-ChildItem -Path "$EngineDir/Source" -Directory

foreach ($DirItem in $EngineSourceDirItems)
{
    if (!($DirItem.Name -ieq "ThirdParty"))
    {
        Write-Debug "Scan Engine Source Dir: $($DirItem.FullName)"
        $TempDirs += Get-ChildItem -Path $DirItem.FullName -Directory -Recurse `
            | Where-Object { `
                      ($_.Name -ieq 'Binaries') `
                  -or ($_.Name -ieq 'Intermediate') `
          }
    }
}


# *.sln files in the root folder
$TempFiles = Get-ChildItem -Path $Path -File `
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

if ($DryRun)
{
    Write-Warning "Exiting without generating project files due to -DryRun"
    exit 151
}

& "$Path/GenerateProjectFiles.bat"
