#!/usr/bin/env pwsh
#
# P4Config2ENV.ps1
#
# See: https://github.com/XistGG/UnrealXistTools/
#
#   This script will search the given Path for a relevant .p4config NAME=VALUE
#   file, searching parent directories as needed until one is found.
#
#   If you set the -Export flag, these NAME=VALUE will be exported to the system
#   environment, such that you can then start Rider or VS and they will have the
#   appropriate information available to connect to P4.
#
#   Without the -Export flag, this will return a dict containing the info.
#

[CmdletBinding()]
param(
    [switch]$Export,
    [Parameter()]$Path
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

$ScriptName = $MyInvocation.MyCommand.Name


################################################################################
##  Functions
################################################################################

function FindP4ConfigFile()
{
    param(
        [string]$Directory
    )

    # If $Directory is not a valid directory, there is no .p4config here
    $dir = Get-Item -Path $Directory 2> $null
    if (!$dir -or !$dir.Exists -or !$dir.PSIsContainer)
    {
        return $null
    }

    # Try to find .p4config in $Directory
    Write-Debug "Searching for .p4config in: $($dir.FullName)"
    $filename = Join-Path $dir.FullName ".p4config"
    $p4config = Get-ChildItem -Path $filename -File -Force 2> $null

    # If we found a .p4config in this $Directory, return it
    if ($p4config -and $p4config.Exists)
    {
        Write-Debug "Found .p4config: $($p4config.FullName)"
        return $p4config
    }

    # No .p4config in this directory.
    # Recursively search parent directories until we get to the root.
    if ($dir.Parent -and $dir.Parent.Exists)
    {
        return FindP4ConfigFile -Directory:$dir.Parent.FullName
    }

    # There is no parent directory, we're already at the root
    return $null
}


function GetP4Config()
{
    param(
        [System.IO.FileInfo]$P4ConfigItem
    )

    begin
    {
        $result = @{}

        # Open the .p4config for reading
        # System.IO.StreamReader REQUIRES AN ABSOLUTE PATH TO THE FILE
        $file = New-Object System.IO.StreamReader($P4ConfigItem.FullName)
        if (!$file)
        {
            throw "Cannot open file: $($P4ConfigItem.FullName)"
        }
    }

    process
    {
        $LineNum = 0
        while (($line = $file.readline()) -ne $null)
        {
            $LineNum++

            # Trim all leading and trailing whitespace
            $line = $line.Trim()

            # Skip blank lines
            if ($line -eq "")
            {
                Write-Debug "Skip blank line $LineNum"
                continue
            }

            # Skip comment lines
            if ($line[0] -eq "#")
            {
                Write-Debug "Skip comment line ${LineNum}: $line"
                continue
            }

            # Process this line
            Write-Debug "[Line $LineNum] $line"

            if ($line -match "^([^=]+)=(.*)")
            {
                $key = $matches[1]
                $val = $matches[2]

                #Write-Debug "key($key) val($val)"
                $result[$key] = $val
            }
            else
            {
                Write-Error "Malformed line detected in $($P4ConfigItem.FullName)"
                throw "Error in .p4config line $LineNum near: $line"
            }
        }
    }

    end
    {
        [void] $file.Dispose()

        return $result
    }
}


################################################################################
##  Main
################################################################################

# If not otherwise specified, $Path is the current directory
if (!$Path)
{
    $Path = Get-Location
}

# Do nothing if starting in an invalid path
if (!(Test-Path -Path:$Path -PathType Container))
{
    throw "Path ($Path) is not a valid directory"
}

# Find the .p4config in the given path
$p4config = $null
$P4ConfigItem = FindP4ConfigFile -Directory:$Path
if ($P4ConfigItem -and $P4ConfigItem.Exists)
{
    $p4config = GetP4Config -P4ConfigItem:$P4ConfigItem
}

if (!$p4config)
{
    # Write to stdout so the dev knows why they don't have any p4config
    # in the $ENV; it's because there is no relevant file anywhere!
    Write-Host "${ScriptName}: No relevant .p4config found"
    return $null
}

if ($Export)
{
    # We both have a file AND the dev wants us to export its settings
    # into $ENV
    Write-Debug "Exporting $($P4ConfigItem.FullName) into `$ENV"

    foreach ($key in $p4config.Keys)
    {
        $val = $p4config[$key]

        [Environment]::SetEnvironmentVariable($key, $val)
    }

    Write-Host "${ScriptName}: Exported $($P4ConfigItem.FullName) to the environment"
    return $null
}

# If we're NOT in export mode, then return the p4config dict
return $p4config
