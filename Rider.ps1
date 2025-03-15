#!/usr/bin/env pwsh
#
# Rider.ps1
#
# Open Rider for the given Uproject (or -Sln)
#
# For this to work, set your JetBrains Toolbox to use the script name "Rider1"
# for the version of Rider you want to use by default.
#
# Conversely, override $env:RiderCommand to set an alternate default.
#

[CmdletBinding()]
param(
    [Parameter()]$Path,
    [switch]$Sln
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

# Set $env:RiderCommand to override the default value
$RiderCommand = $env:RiderCommand ? $env:RiderCommand : "Rider1"


################################################################################
##  Main
################################################################################

if ($Sln)
{
    # Require a valid $UProjectSln
    Write-Debug "Compute UProjectSln Path=[$Path]"

    $UProjectSln =& $PSScriptRoot/UProjectSln.ps1 -Path:$Path

    if (!$UProjectSln -or !$UProjectSln.Exists)
    {
        throw "Path is not a Solution: $Path"
    }

    # Start Rider for the .sln
    $RiderFile = $UProjectSln
}
else
{
    # Require a valid $UProjectFile
    Write-Debug "Compute UProjectFile Path=[$Path]"

    $UProjectFile =& $PSScriptRoot/UProjectFile.ps1 -Path:$Path

    if (!$UProjectFile -or !$UProjectFile.Exists)
    {
        throw "Path is not a UProject: $Path"
    }

    # Start Rider for the .uproject
    $RiderFile = $UProjectFile
}


# Locate a .p4config and export it to the system environment before starting Rider
& $PSScriptRoot/P4Config.ps1 -Export -Path $RiderFile.Directory.FullName

# Start Rider in the requested mode

if ($IsLinux)
{
    # In Linux, we need to force Rider into the background and suppress its output.
    # We'll use nohup for that.

    # PowerShell won't let us redirect BOTH stderr AND stdout to /dev/null because reasons,
    # so we'll use bash output redirection to do that.

    $startCommand = @( "bash", "-c", "`"$RiderCommand $($RiderFile.FullName)`"",
        ">", "/dev/null", "2>&1" )
    Write-Debug "EXEC: nohup $startCommand"
    Start-Process -NoNewWindow -FilePath nohup -ArgumentList $startCommand -RedirectStandardError /dev/null
}
else
{
    # In Windows/Mac, this is automatically backgrounded and there is no output to consider.

    Write-Debug "EXEC: Rider [$RiderCommand] on [$($RiderFile.FullName)]"
    & $RiderCommand $RiderFile.FullName
}
