#!/usr/bin/env pwsh
#
# Idea.ps1
#
# Open IntelliJ Idea for the given project root directory
#
# For this to work, set your JetBrains Toolbox to use the script name "Idea1"
# for the version of Idea you want to use by default.
#
# Conversely, override $env:IdeaCommand to set an alternate default.
#

[CmdletBinding()]
param(
    [Parameter()]$Path
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

# Set $env:IdeaCommand to override the default value
$IdeaCommand = $env:IdeaCommand ? $env:IdeaCommand : "Idea1"

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

# Locate a .p4config and export it to the system environment before starting Idea
& $PSScriptRoot/P4Config.ps1 -Export -Path $PathItem.FullName

# Start Idea in the requested directory

if ($IsLinux)
{
    # In Linux, we need to force Idea into the background and suppress its output.
    # We'll use nohup for that.

    # PowerShell won't let us redirect BOTH stderr AND stdout to /dev/null because reasons,
    # so we'll use bash output redirection to do that.

    $bashArgs = @( "-c", "`"nohup $IdeaCommand $($PathItem.FullName) > /dev/null 2>&1`"" )
    Write-Debug "EXEC: bash $bashArgs"
    Start-Process -NoNewWindow -FilePath bash -ArgumentList $bashArgs
}
else
{
    # In Windows/Mac, this is automatically backgrounded and there is no output to consider.

    Write-Debug "EXEC: Idea [$IdeaCommand] on [$($PathItem.FullName)]"
    & $IdeaCommand $PathItem.FullName
}
