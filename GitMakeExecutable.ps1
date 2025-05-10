#!/usr/bin/env pwsh
#
# GitMakeExecutable.ps1
#
#	Make the given files Executable.
#	
#	- Mark them chmod +x in Git.
#	- On Linux+Mac, also set the executable file system bit.
#

[CmdletBinding()]
param(
	[Parameter(ValueFromRemainingArguments=$true, Position=0)]
	[string[]] $files
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

##
##  Main
##

if (-not $files -or -not $files.Count)
{
	$ScriptName = $MyInvocation.MyCommand.Name
	Write-Error "Usage: $ScriptName file1 [file2] [...] [fileN]"
	exit(1)
}

$numErrors = 0

foreach ($file in $files)
{
	if (-not (Test-Path $file))
	{
		$numErrors += 1
		Write-Error "No such file: $file"
		continue
	}

	Write-Host "Make executable: $file"

	Write-Debug "EXEC: git update-index --chmod=+x $file"
	& git update-index --chmod=+x $file
	if ($LASTEXITCODE -ne 0) { $numErrors += 1 }

	if ($IsLinux -or $IsMacOS)
	{
		Write-Debug "EXEC: chmod 755 $file"
		& chmod "755" $file
		if ($LASTEXITCODE -ne 0) { $numErrors += 1 }
	}
}

$exitCode = $numErrors -eq 0 ? 0 : 2
exit($exitCode)
