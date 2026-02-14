<#
.SYNOPSIS
    Runs all Pester tests in the Tests/ directory.
#>
$ErrorActionPreference = "Stop"

# Ensure Pester is available
if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Warning "Pester module not found. Attempting to install..."
    Install-Module Pester -Scope CurrentUser -Force -SkipPublisherCheck
}

# Run tests
Invoke-Pester -Path "$PSScriptRoot/Tests"
