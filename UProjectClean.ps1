#
# UnrealProjectClean.ps1
#

[CmdletBinding()]
param(
    [switch]$Quiet,
    [Parameter()] $UProjectFile
)


# If user didn't specify a project file, default to current directory
if ((!$PSBoundParameters.ContainsKey('UProjectFile')) -or ($UProjectFile -eq ''))
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


################################################################################
###  Generate Project Files
################################################################################

. $PSScriptRoot\UnrealVersionSelector.ps1 -quiet -projectfiles $UProjectFile
