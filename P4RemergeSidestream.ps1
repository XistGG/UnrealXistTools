#!/usr/bin/env pwsh
#
# P4RemergeSidestream.ps1
#
#   When you run this, you will need to ensure your $env:P4* settings are appropriate
#   to run `p4 describe -s $CL` on the -SourceDepot.
#
# Example Usage:
#
#   P4RemergeSidestream.ps1 -CL 362 -SourceDepot //XE/Lyra-Xist -SourceDir D:\Dev\Lyra-Xist -LocalDir D:\MyEngine\MyProject
#
#   In the above example, I have a //XE/Lyra-Xist stream in D:/Dev/Lyra-Xist,
#   and I merged some changes from upstream Epic //UE5/Main/Samples/Games/Lyra into
#   //XE/Lyra-Xist in CL #362.
#
#   My current project stream isn't derived from that, it's derived from my custom engine stream,
#   which doesn't have Lyra in it.  So Lyra is a "side stream", not an "up stream".
#
#   Now I want to merge those same changes into my local project in the current directory
#   (D:/MyEngine/MyProject), so I run P4RemergeSidestream.ps1 to essentially duplicate the
#   file operations (delete or add/modify) on my project.
#
#   If you pass -TranslationRules then the source files will be translated using these rules.
#   As soon as a translation rule affects a local path, subsequent rules stop processing.
#   Thus, make sure you order your -TranslationRules accordingly, if you use any.
#   For an example see P4RemergeLyraExample.ps1 which defines the translations I'm using.
#

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string] $CL,

    [Parameter(Mandatory=$true)]
    [string] $SourceDepot,

    [Parameter(Mandatory=$true)]
    [string] $SourceDir,

    [string] $LocalDir = $null,  # Current directory by default

    [HashTable] $TranslationRules = $null,

    [switch] $Force
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

# Import the P4 helper module
Import-Module -Name $PSScriptRoot/Modules/P4.psm1

################################################################
# Determine where we're re-merging to
################################################################

if ($LocalDir)
{
    # Verify $LocalDir is a valid directory
    $item = Get-Item -Force -Path $LocalDir
    if (-not $item -or -not $item.PSIsContainer)
    {
        throw "-LocalDir ($LocalDir) is an invalid directory"
    }
    # Get the absolute path to $LocalDir
    $LocalDir = $item.FullName
}
else
{
    # Default $LocalDir is the current directory
    $LocalDir = Get-Location
}

if (!(Test-Path -Path $SourceDir -PathType Container))
{
    throw "-SourceDir ($SourceDir) does not exist"
}

################################################################
# Make sure $SourceDepot ends with a '/'
################################################################

if (!$SourceDepot -or $SourceDepot.Length -lt 3 -or $SourceDepot.Substring(0, 2) -ne '//')
{
    throw "-SourceDepot must be a //Depot/Path"
}

if ($SourceDepot[$SourceDepot.Length-1] -ne '/')
{
    $SourceDepot = "$SourceDepot/"
}

################################################################
# Confirm re-merge parameters
################################################################

Write-Host "Remerge Sidestream $SourceDepot/...@$CL"

if ($TranslationRules -ne $null)
{
    foreach ($regexpMatch in $TranslationRules.Keys)
    {
        Write-Host "  with Translation: '$regexpMatch' ==> '$($TranslationRules[$regexpMatch])'"
    }
}

if (!$Force)
{
    $response = Read-Host "Remerge into `"$LocalDir`"? (y|N) [N] "
    $confirmed = $response -ieq 'y'

    if (!$confirmed)
    {
        Write-Host "Operation cancelled by user."
        return 1
    }
}

################################################################
# Utility Functions
################################################################

function TranslateLocalPath
{
    param(
        [Parameter(Position=0)]
        [string] $RelativePath
    )

    if ($TranslationRules -ne $null)
    {
        foreach ($regexpMatch in $TranslationRules.Keys)
        {
            $regexpReplace = $TranslationRules[$regexpMatch]

            # Try to match/replace with this rule
            $temp = $RelativePath -replace $regexpMatch, $regexpReplace

            # This rule matched and replaced, stop processing
            if ($temp -ne $RelativePath)
            {
                Write-Debug "Translated path `"$RelativePath`" to `"$temp`""
                return $temp
            }
        }
    }

    return $RelativePath
}

function CreateBaseDirIfNeeded
{
    param(
        [Parameter(Position=0)]
        [string] $Path
    )

    if (!$Path)
    {
        throw "Usage: CreateBaseDirIfNeeded -Path <PATH>"
    }

    $parentDir = Split-Path -Path $Path

    if (-not (Test-Path -Path $parentDir -PathType Container))
    {
        # $parentDir does not exist, try to create it (and any of its parents that are missing)
        New-Item -ItemType Directory -Path $parentDir -Force > $null
        if ($LASTEXITCODE -ne 0)
        {
            Write-Error "Failed to create directory: $parentDir"
            throw "Resolve directory permission errors and try again"
        }
    }
}

################################################################
# Execute the re-merge
################################################################

$change =& P4_Describe -CL:$CL

for ($i=0; $i -lt $change.Files.Count; $i++)
{
    $file = $change.Files[$i]
    $fileNum = 1 + $i

    if ($file.Path.Substring(0, $SourceDepot.Length) -ne $SourceDepot)
    {
        Write-Host "File $fileNum/$($change.Files.Count) [SKIP] is not under ${SourceDepot}: $($file.Path)"
        continue
    }

    $relativePath = $file.Path.Substring($SourceDepot.Length)
    $relativeLocalPath = TranslateLocalPath $relativePath

    if ($relativeLocalPath -eq "")
    {
        Write-Host "File $fileNum/$($change.Files.Count) [SKIP] is an ignored path: $relativePath"
        continue
    }

    $sourcePath = Join-Path $SourceDir $relativePath  # may not exist
    $localPath = Join-Path $LocalDir $relativeLocalPath  # may not exist

    if ($file.ChangeType -eq "delete" -or $file.ChangeType -eq "move/delete")
    {
        # Make sure the file is deleted from $localPath
        if (Test-Path -Path $localPath)
        {
            Remove-Item -Path $localPath -Force -ErrorAction Stop
            if ($LASTEXITCODE -ne 0)
            {
                Write-Error "File $fileNum/$($change.Files.Count) ($($file.Path)) delete failed: $localPath"
                throw "Cancelled re-merge; check command parameters and try again"
            }
        }
        Write-Host "File $fileNum/$($change.Files.Count) Delete: $localPath"
        continue
    }

    if ($file.ChangeType -eq "branch" -or $file.ChangeType -eq "integrate" -or $file.ChangeType -eq "move/add")
    {
        if (Test-Path -Path $sourcePath)
        {
            # Make sure the local parent dir exists before we copy the path
            CreateBaseDirIfNeeded -Path $localPath

            # Copy the (new or modified) file from $sourcePath to $localPath
            Copy-Item -Force -Path $sourcePath -Destination $localPath -ErrorAction Stop
            if ($LASTEXITCODE -ne 0)
            {
                Write-Error "File $fileNum/$($change.Files.Count) ($($file.Path)) copy failed to: $localPath"
                throw "Cancelled re-merge; check command parameters and try again"
            }
            Write-Host "File $fileNum/$($change.Files.Count) Copy: $localPath (<< $sourcePath)"
        }
        else
        {
            Write-Warning "File $fileNum/$($change.Files.Count) ($($file.Path)) source does not exist: $sourcePath"
        }

        continue
    }

    # If we're here, this is some ChangeType that we don't yet know what to do with.
	Write-Error "Unknown change type, please submit a bug report."

	Write-Host "Applicable file info:"
    $file | Format-List

    throw "Unknown ChangeType '$($file.ChangeType)': Please submit a bug report"
}

Write-Host ""
Write-Host "Remerge complete. Check source control to see what changed and resolve any conflicts."
Write-Host "You will need to reconcile any files/directories that changed in:"
Write-Host "$LocalDir"
Write-Host ""
