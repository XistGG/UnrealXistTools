#!/usr/bin/env -S pwsh -NoLogo
#Requires -Version 7.0
<#
.SYNOPSIS
    Runs the Pester 5 tests on Windows, macOS, or Linux.
.PARAMETER Path
    Test files or directories to run. Defaults to this repository's Tests directory,
    regardless of the current working directory.
.NOTES
    Installs the pinned Pester version for the current user if needed.
    Test, discovery, or setup failures (and an empty suite) produce a nonzero exit
    code when invoked with pwsh -File.
#>
[CmdletBinding()]
param(
    [string[]]$Path = @("$PSScriptRoot/Tests")
)

$ErrorActionPreference = 'Stop'

# Use the same tested version locally and in CI, even if Pester 4 or a newer
# incompatible version is installed alongside it.
$pesterVersion = '5.7.1'
if (-not (Get-Module -ListAvailable -Name Pester | Where-Object Version -EQ $pesterVersion)) {
    Write-Host "Installing Pester $pesterVersion for the current user..."
    # Windows may ship a legacy Pester signed by Microsoft rather than the
    # publisher of current Gallery releases.
    Install-Module Pester -RequiredVersion $pesterVersion -Repository PSGallery -Scope CurrentUser -Force -SkipPublisherCheck
}
Import-Module Pester -RequiredVersion $pesterVersion -Force -ErrorAction Stop

$config = New-PesterConfiguration
$config.Run.Path = $Path
$config.Run.PassThru = $true
$config.Run.Throw = $true
$config.Output.Verbosity = 'Detailed'
$result = Invoke-Pester -Configuration $config

if ($null -eq $result -or $result.TotalCount -eq 0) {
    throw 'No tests were discovered. Check the test path and *.Tests.ps1 filenames.'
}
