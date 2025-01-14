#!/usr/bin/env pwsh
#
# P4ObliterateIgnoredFiles.ps1
#
#   Iterate through the local files, and for every file that SHOULD be ignored,
#   yet exists in the P4 depot anyway, obliterate it from P4.
#
#   Pass the -y flag to actually obliterate, otherwise it will just tell you what
#   it would have done if you had passed the -y flag.
#
#   Note that you need to have permission to obliterate on the P4 server for this
#   to work.  ($env:P4USER = "admin" will do the trick, if you have the password).
#

[CmdletBinding()]
param(
    [switch] $y,
    [string] $Path = "."
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

# Import the P4 helper module
Import-Module -Name $PSScriptRoot/Modules/P4.psm1


$BatchSize = 50
$IgnoredFiles = New-Object System.Collections.ArrayList
$TestFiles = New-Object System.Collections.ArrayList


function HandlePendingIgnoredFiles
{
    #Write-Debug "HandlePendingIgnoredFiles $($script:IgnoredFiles.Count)"

    if ($script:IgnoredFiles.Count -gt 0)
    {
        $result =& P4_FStat -Paths $script:IgnoredFiles 2> $null

        $obliterates = New-Object System.Collections.ArrayList

        foreach ($file in $script:IgnoredFiles)
        {
            $found = $false
            foreach ($fstat in $result)
            {
                if ($fstat.clientFile -ieq $file)
                {
                    $found = $true
                    break;
                }
            }

            if ($found)
            {
                # The depot contains this file, which is supposed to be ignored.
                Write-Debug "OBLITERATE: $file"

                $obliterates.Add($file) > $null
            }
        }

        # If we need to obliterate some files then do it
        if ($obliterates.Count -gt 0)
        {
            if ($y)
            {
                # The "-y" switch was passed, so actually do obliterate these files
                p4 obliterate -y @obliterates
            }
            else
            {
                # No "-y" switch on the command line, so DO NOT actually obliterate the files,
                # instead just show which files WOULD BE obliterated with the "-y" switch.
                p4 obliterate @obliterates
            }
        }
    }

    $script:IgnoredFiles.Clear()
}


function ProcessIgnoredFile
{
    [CmdletBinding()]
    param(
        [string] $File
    )

    $script:IgnoredFiles.Add($File) > $null

    if ($script:IgnoredFiles.Count -ge $BatchSize)
    {
        &HandlePendingIgnoredFiles
    }
}


function ObliterateIgnoredFiles
{
    [CmdletBinding()]
    param(
        [System.Collections.ArrayList] $Files
    )

    #Write-Debug "ObliterateIgnoredFiles $($Files.Count)"

    $result =& P4_FilterIgnoredPaths -Paths $Files

    # If there are any files that should be ignored in this batch,
    # determine if they need to be obliterated
    foreach ($file in $result.IgnoredPaths)
    {
        &ProcessIgnoredFile -File $file
    }
}


function ObliterateFileIfIgnored
{
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)] $File
    )

    process
    {
        if ($File -and $File.Exists)
        {
            $script:TestFiles.Add($File.FullName) > $null

            if ($script:TestFiles.Count -ge $BatchSize)
            {
                &ObliterateIgnoredFiles -Files $script:TestFiles
                $script:TestFiles.Clear()
            }
        }
    }
}


Write-Debug "Processing Path: $Path"
Get-ChildItem -Path $Path -Recurse -File | ObliterateFileIfIgnored

# Finish processing the test files buffer if needed
if ($TestFiles.Count -gt 0)
{
    &ObliterateIgnoredFiles -Files $TestFiles
    $TestFiles.Clear()
}

# Finish processing the obliterate buffer if needed
&HandlePendingIgnoredFiles
