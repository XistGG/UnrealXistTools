#!/usr/bin/env pwsh
#
# GitMakeExecutable.ps1
#
#	Make the given files Executable.
#	
#	- Mark them chmod +x in Git.
#	- On Linux+Mac, also chmod +x in the worktree.
#

[CmdletBinding()]
param(
	[Parameter(ValueFromRemainingArguments = $true, Position = 0)]
	[string[]] $files
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

##
##  Main
##

if (-not $files -or -not $files.Count) {
	$ScriptName = $MyInvocation.MyCommand.Name
	Write-Error "Usage: $ScriptName file1 [file2] [...] [fileN]"
	exit(1)
}

$numErrors = 0

$resolvedFiles = @()
foreach ($filePattern in $files) {
	$paths = Resolve-Path -Path $filePattern -ErrorAction SilentlyContinue
	if (-not $paths) {
		$numErrors += 1
		Write-Error "No such file or pattern: $filePattern"
		continue
	}
	foreach ($pathInfo in $paths) {
		$resolvedFiles += $pathInfo.ProviderPath
	}
}

$resolvedFiles = $resolvedFiles | Select-Object -Unique

foreach ($file in $resolvedFiles) {
	Write-Host "Make executable: $file"

	Write-Debug "EXEC: git update-index --chmod=+x $file"
	& git update-index --chmod=+x $file
	if ($LASTEXITCODE -ne 0) { $numErrors += 1 }

	if ($IsLinux -or $IsMacOS) {
		Write-Debug "EXEC: chmod +x $file"
		& chmod +x $file
		if ($LASTEXITCODE -ne 0) { $numErrors += 1 }
	}
}

$exitCode = $numErrors -eq 0 ? 0 : 2
exit($exitCode)
