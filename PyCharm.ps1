#!/usr/bin/env pwsh
#
# PyCharm.ps1
#
# Open PyCharm for the given project root directory
#
# For this to work, set your JetBrains Toolbox to use the script name "PyCharm1"
# for the version of PyCharm you want to use by default.
#
# Conversely, override $env:PyCharmCommand to set an alternate default.
#

[CmdletBinding()]
param(
    [Parameter()]$Path
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

# Set $env:PyCharmCommand to override the default value
$PyCharmCommand = $env:PyCharmCommand ? $env:PyCharmCommand : "PyCharm1"

$PathItem = Get-Item -Path $(Get-Location)  # Default: current directory

if ($Path -ne $null -and $Path -ne "")
{
    $PathItem = Get-Item -Path $Path
}

if (-not $PathItem)
{
    throw "Invalid Path: [$Path]"
}

################################################################################
##  Main
################################################################################

# Locate a .p4config and export it to the system environment before starting PyCharm
& $PSScriptRoot/P4Config.ps1 -Export -Path $PathItem.FullName

# Start PyCharm in the requested directory

if ($IsLinux)
{
    # In Linux, we need to force PyCharm into the background and suppress its output.
    # We'll use nohup for that.

    # PowerShell won't let us redirect BOTH stderr AND stdout to /dev/null because reasons,
    # so we'll use bash output redirection to do that.

    $bashArgs = @( "-c", "`"nohup $PyCharmCommand $($PathItem.FullName) > /dev/null 2>&1`"" )
    Write-Debug "EXEC: bash $bashArgs"
    Start-Process -NoNewWindow -FilePath bash -ArgumentList $bashArgs
}
else
{
    # In Windows/Mac, this is automatically backgrounded and there is no output to consider.

    Write-Debug "EXEC: PyCharm [$PyCharmCommand] on [$($PathItem.FullName)]"
    & $PyCharmCommand $PathItem.FullName
}
