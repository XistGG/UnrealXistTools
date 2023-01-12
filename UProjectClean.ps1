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

pushd $UProjectDirectory

$TempDirs = Get-ChildItem -Recurse | where {$_.PSIsContainer} `
    | where {$_.Name -cmatch '^Binaries$' `
         -or $_.Name -cmatch '^Intermediate$' `
      }

popd

foreach ($TempDir in $TempDirs)
{
    Write-Host "[-] $TempDir"
    Remove-Item -Force -Recurse $TempDir
}

# If we output a bunch of deleted directories, add whitespace line after
if ($TempDirs.count -gt 0)
{
    Write-Host ""
}


################################################################################
###  Generate Project Files
################################################################################

. $PSScriptRoot\UnrealVersionSelector.ps1 -quiet -projectfiles $UProjectFile
