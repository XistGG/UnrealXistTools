#
# UnrealProjectClean.ps1
#
# See: https://github.com/XistGG/UnrealXistTools/
#
# Clean an Unreal Project
#
#   - Remove Binaries dirs
#   - Remove Intermediate dirs
#   - Generate Project Files
#

[CmdletBinding()]
param(
    [switch]$Quiet,
    [Parameter()] $UProjectFile
)


# If user didn't specify a project file, default to current directory
if (!$PSBoundParameters.ContainsKey('UProjectFile'))
{
    $UProjectFile = '.'
}
. $PSScriptRoot\UProjectFile.ps1


################################################################################
###  CLEAN Binaries + Intermediate folders
################################################################################

# All directories at any depth named 'Binaries' or 'Intermediate'
$TempDirs = Get-ChildItem -Path $UProjectDirectory -Recurse `
    | where {$_.PSIsContainer `
        -and ( `
              ($_.Name -cmatch '^Binaries$') `
          -or ($_.Name -cmatch '^Intermediate$') `
        ) `
      }

# *.sln files in the root folder
$TempFiles = Get-ChildItem -Path $UProjectDirectory `
    | where {(!$_.PSIsContainer) `
        -and ($_.Name -cmatch '\.sln$') `
      }

foreach ($TempDir in $TempDirs)
{
    Write-Host "[-] $TempDir"
    Remove-Item -Force -Recurse $TempDir
}

foreach ($TempFile in $TempFiles)
{
    Write-Host "[-] $TempFile"
    Remove-Item -Force $TempFile
}

# If we output any deletes, add whitespace line after
if (($TempDirs.count + $TempFiles.count) -gt 0)
{
    Write-Host ""
}


################################################################################
###  Generate Project Files
################################################################################

. $PSScriptRoot\UnrealVersionSelector.ps1 -quiet -projectfiles $UProjectFile
