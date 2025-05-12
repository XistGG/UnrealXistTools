#!/usr/bin/env pwsh
#
# P4ListIgnoredFiles.ps1
#
#	Recursively iterate $Path and list all existing files that SHOULD BE IGNORED
#	by P4. Write one file per output line.
#

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)] [string]$Path = ".", # Default: Current Directory
	[int32] $BatchSize = 100
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

# Import the P4 helper module
Import-Module -Name $PSScriptRoot/Modules/P4.psm1

$InputBuffer = New-Object System.Collections.ArrayList


function TestForIgnoredFiles
{
    [CmdletBinding()]
    param(
        [System.Collections.ArrayList] $Files
    )

	# Test $Files to see which should be ignored
    $result =& P4_FilterIgnoredPaths -Paths $Files

	# We're only interested in files that SHOULD BE IGNORED.
	# Output the files we're supposed to ignore.
    foreach ($file in $result.IgnoredPaths)
    {
    	Write-Output $file
    }
}

function FlushOutput
{
	if ($script:InputBuffer.Count -gt 0)
	{
	    &TestForIgnoredFiles -Files $script:InputBuffer
	    $script:InputBuffer.Clear()
	}
}

function IngestFile
{
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)] $File
    )

    process
    {
        if ($File -and $File.Exists)
        {
            [void] $script:InputBuffer.Add($File.FullName)

            if ($script:InputBuffer.Count -ge $BatchSize)
            {
            	&FlushOutput
            }
        }
    }
}

####
####  Main
####

if (-not (Test-Path -Path $Path))
{
	throw "Invalid Path: $Path"
}

Write-Debug "Scanning Path: [$Path]"

# We -Force so dotfiles are also processed; we want ALL files
Get-ChildItem -Force -Path $Path -Recurse -File | IngestFile

FlushOutput
