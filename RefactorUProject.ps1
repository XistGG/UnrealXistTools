#!/usr/bin/env pwsh
#
# RefactorUProject.ps1
#
#   ==== Refactor an Unreal Engine Project ====
#
#   Note we CANNOT rename or modify the contents of UAsset files.
#   For this reason, this refactor WILL BREAK YOUR PROJECT.
#
#   We refactor all C++ names and INI names, but we DO NOT modify
#   any Blueprint or other UAsset names.
#
#   This means if you have B_OldAsset.uasset and it gets refactored
#   to B_NewAsset.uasset then the C++ and the INI will use the new
#   name, but the asset will still have the old name.
#
#   You'll need to compile the C++ and start UEditor to then manually
#   fix any assets that need to be fixed and coordinate their names
#   with the INIs and C++.
#
# Example:
#
####
##
## ## Clone https://github.com/XistGG/XistCommonGameSample and then refactor it
## RefactorUProject.ps1 -From D:/Github/XistCommonGameSample -To D:/Temp/NewGame -OldPackageName XistCommonGameSample -NewPackageName NewProject -OldCodePrefix Xcgs -NewCodePrefix Noob -Debug -Force
##
## ## Generate project files
## UProjectClean.ps1 D:/Temp/NewGame/NewProject.uproject
##
## ## Open Rider, Build "NewProject" project
## rider D:/Temp/NewGame/NewProject.uproject
##
## ## Run game from Rider
## ## RE-SAVE ALL BINARY ASSETS
## ## Now it's safe to remove the [CoreRedirects] in NewProject's Config/DefaultEngine.ini
##
####

[CmdletBinding()]
param(
    [Parameter(Mandatory)]$From,
    [Parameter(Mandatory)]$To,
    [Parameter(Mandatory)]$OldPackageName,
    [Parameter(Mandatory)]$NewPackageName,
    [Parameter(Mandatory)]$OldCodePrefix,
    [Parameter(Mandatory)]$NewCodePrefix,
    [Switch]$Force
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

################################################################################
##  Validate Parameters
################################################################################

if (!$From)
{
    throw "Missing required parameter: -From"
}

# This will throw an exception if $From is not a valid UProject file
$FromUProjectFile =& $PSScriptRoot/UProjectFile.ps1 -Path:$From


if (!$To)
{
    throw "Missing required parameter: -To"
}

if ($To -imatch '\.uproject$')
{
    throw "The -To parameter should be a directory name, not a .uproject name"
}

# we hope this fails, we don't want to see stderr output
$ToItem = Get-Item -Path $To 2> $null

if ($ToItem -and $ToItem.Exists)
{
    if ($Force)
    {
        Write-Debug "Removing existing -To dir (due to -Force)..."
        Remove-Item -Path $ToItem.FullName -Recurse -Force
        $ToItem = Get-Item -Path $To 2> $null

        if ($ToItem)
        {
            throw "Failed to delete directory"
        }
    }
    else
    {
        Write-Error "-To item exists; stopping refactor. Either change -To or move the existing file/directory out of that location."
        throw "Unable to refactor an existing -To project: $($ToItem.FullName)"
    }
}


################################################################################
##  Methods
################################################################################

function RefactorNames()
{
    param (
        [Parameter(Mandatory,ValueFromRemainingArguments=$true)] $Content
    )

    $OldUpper = $OldPackageName.ToUpper()
    $NewUpper = $NewPackageName.ToUpper()

    $OldCodePrefixUpper = $OldCodePrefix.ToUpper()
    $NewCodePrefixUpper = $NewCodePrefix.ToUpper()

    return $Content `
        -creplace $OldPackageName,$NewPackageName `
        -creplace $OldUpper,$NewUpper `
        -creplace $OldCodePrefix,$NewCodePrefix `
        -creplace $OldCodePrefixUpper,$NewCodePrefixUpper `
    ;
}


function CreateDirectory()
{
    param (
        [Parameter(Mandatory,ValueFromRemainingArguments=$true)] $Path
    )

    $Item = Get-Item -Path $Path 2> $null  # squelch "not found" errors

    if ($Item -and $Item.Exists -and !$Item.PSIsContainer)
    {
        throw "Directory already exists and is not a directory: $Path"
    }

    if (!$Item -or !$Item.Exists)
    {
        Write-Debug "Creating directory: $Path"

        $Item = New-Item -Path $Path -ItemType "directory"

        if (!$Item -or !$Item.Exists)
        {
            throw "Failed to create directory: $Path"
        }
    }

    # Return the directory that already existed or was now created
    return $Item
}


function WriteCoreRedirects()
{
    param (
        [Parameter(Mandatory)]$ToIni
    )

    # Open the destination DefaultEngine.ini so we can add [CoreRedirects]
    $Content = Get-Content -Path $ToIni

    $Content += ""
    $Content += "[CoreRedirects]"

    foreach ($OldName in $CoreRedirects['class'].Keys)
    {
        $NewName = $CoreRedirects['class'][$OldName]
        $Line = "+ClassRedirects=(OldName=`"/Script/$OldPackageName.$OldName`",NewName=`"/Script/$NewPackageName.$NewName`")"
        $Content += $Line
        Write-Debug $Line
    }
    foreach ($OldName in $CoreRedirects['struct'].Keys)
    {
        $NewName = $CoreRedirects['struct'][$OldName]
        $Line = "+StructRedirects=(OldName=`"/Script/$OldPackageName.$OldName`",NewName=`"/Script/$NewPackageName.$NewName`")"
        $Content += $Line
        Write-Debug $Line
    }
    foreach ($OldName in $CoreRedirects['enum'].Keys)
    {
        $NewName = $CoreRedirects['enum'][$OldName]
        $Line = "+EnumRedirects=(OldName=`"/Script/$OldPackageName.$OldName`",NewName=`"/Script/$NewPackageName.$NewName`")"
        $Content += $Line
        Write-Debug $Line
    }

    # List packages LAST in case CoreRedirect is a "first to match" type search.
    # This is intended to be the catch-all for anything we didn't explicitly redirect already.
    $Line = "+PackageRedirects=(OldName=`"/Script/$OldPackageName`",NewName=`"/Script/$NewPackageName`")"
    $Content += $Line
    Write-Debug $Line

    # Rewrite $ToIni with our [CoreRedirects]
    $Content | Set-Content -Path $ToIni
}


function DuplicateSourceFile()
{
    param (
        [Parameter(Mandatory)]$FromFile,
        [Parameter(Mandatory)]$ToDir,
        [Parameter()]$FromContentRoot,
        [Switch]$KeepRelativity
    )

    if (!$KeepRelativity -or !$FromContentRoot)
    {
        $ToName = RefactorNames $FromFile.Name
        $ToFile = Join-Path $ToDir.FullName $ToName

        #Write-Debug "[0] ToName [$ToName] ToFile [$ToFile]"
    }
    else
    {
        # Want to keep filename relativity to the root
        $RelativePath = $FromFile.FullName.substring($FromContentRoot.FullName.length)
        $RelativeRefactoredName = RefactorNames $RelativePath

        # Now compute $ToName and $ToFile based on the relative $FromFile path
        $ToName = Split-Path $RelativeRefactoredName -Leaf
        $ToFile = Join-Path $ToDir.FullName $RelativeRefactoredName

        #Write-Debug "[1] ToName [$ToName] ToFile [$ToFile]"
    }

    # Sanity check, don't overwrite directories that exist
    $ToFileItem = Get-Item -Path $ToFile 2> $null  # squelch not found errors
    if ($ToFileItem -and $ToFileItem.Exists -and $ToFileItem.PSIsContainer)
    {
        Write-Error "Expected ToFile to be a file, but it is a directory: $($ToFileItem.FullName)"
        throw "ToFile must be a file, you did something wrong"
    }

    # Create $ToFile's parent dir if needed
    $ToFileRoot = Split-Path $ToFile
    $Dir = CreateDirectory -Path $ToFileRoot

    # Create $ToFile's parent directory if needed

    Write-Debug "    * $ToFile <| $FromFile"

    $OriginalSource = Get-Content -Path $FromFile
    $Source = RefactorNames $OriginalSource
    $Source | Set-Content -Path $ToFile

    # If this is a C++ header file, then look for redirects we'll need to make
    if ($FromFile.Extension -ieq '.h')
    {
        # Check $OriginalSource to see if it defines any classes or structs
        # that we need to redirect for the binary assets

        # Create a Regex that looks for the OLD code prefix so we know to rewrite to the new prefix
        $Regex = '(class|struct|enum|enum\s+class)\s+([A-Z]+_API\s+)?([AEFSU])(' + $OldCodePrefix + '[a-zA-Z0-9_]*)'

        $m = ([regex]$Regex).Matches($OriginalSource)
        if ($m)
        {
            for ($i = 0; $i -lt $m.count; $i++)
            {
                $MatchType = $m[$i].groups[1].Value
                $NamePrefix = $m[$i].groups[3].Value
                $OldName = $m[$i].groups[4].Value
                $NewName = RefactorNames $OldName

                # convert 'enum class' to 'enum'
                # nothing else is affected by this
                $MatchType = ($MatchType -split '\s+')[0]

                Write-Debug "REDIRECT MATCH [$($m[0])] ($MatchType($NamePrefix)) [$OldName]->[$NewName]"

                if (!$CoreRedirects.ContainsKey($MatchType))
                {
                    $CoreRedirects[$MatchType] = @{}
                }

                $CoreRedirects[$MatchType][$OldName] = $NewName
            }
        }
    }
}


# In this case we only know the ROOT content folder we're copying into.
# We can deduce the relative file path based on the source content root,
# so that's what we need to do.
#
function CopyUnrealAsset()
{
    param (
        [Parameter(Mandatory)]$FromFile,
        [Parameter(Mandatory)]$FromContentRoot,
        [Parameter(Mandatory)]$ToContentRoot
    )

    $RelativePath = $FromFile.FullName.substring($FromContentRoot.FullName.length);
    $RelativeDir = Split-Path -Path $RelativePath

    # Note for UAsset files we DO NOT modify file names or contents
    $ToFile = Join-Path $ToContentRoot.FullName $RelativeDir $FromFile.Name
    $ToFileParentDir = Split-Path -Path $ToFile

    # Make sure the parent directory of the file we're trying to create exists
    $Dir = CreateDirectory -Path $ToFileParentDir

    Write-Debug "    + $ToFile << $FromFile"
    Copy-Item -Path $FromFile -Destination $ToFile
}


function DuplicateUnrealModule()
{
    param(
        [Parameter(Mandatory)]$FromModule,
        [Parameter(Mandatory)]$ToModule
    )

    Write-Debug "#>>> Duplicate Unreal Module: $ToModule"
    Write-Debug "# From: $FromModule"
    Write-Debug "# To  : $ToModule"

    $ToModuleDir = CreateDirectory -Path $ToModule

    # Filter out files we most certainly DO NOT want to copy from one project to a new project
    # .p4config (new project, surely new p4 config)
    # .vsconfig (generated build file)
    $TopFiles = Get-ChildItem -Path $FromModule -File `
        | Where-Object { `
                 !($_.Name -ieq '.p4config') `
            -and !($_.Name -ieq '.vsconfig') `
            -and !($_.Extension -ieq 'sln') `
        }

    foreach ($File in $TopFiles)
    {
        DuplicateSourceFile -FromFile $File -ToDir $ToModuleDir
    }

    # Filter out directories we certainly DO NOT want to copy
    # .git (git database! huge, project-specific)
    # .idea JetBrains project files
    # .vs VisualStudio project files
    # Binaries,DerivedDataCache,Intermediate,Saved Unreal Engine generated files
    $TopDirs = Get-ChildItem -Path $FromModule -Directory `
        | Where-Object { `
                 !($_.Name -ieq '.git') `
            -and !($_.Name -ieq '.idea') `
            -and !($_.Name -ieq '.vs') `
            -and !($_.Name -ieq 'Binaries') `
            -and !($_.Name -ieq 'DerivedDataCache') `
            -and !($_.Name -ieq 'Intermediate') `
            -and !($_.Name -ieq 'Saved') `
        }

    foreach ($Dir in $TopDirs)
    {
        $ToDirName = RefactorNames $Dir.Name
        $ToDir = Join-Path $ToModuleDir $ToDirName

        Write-Debug "    + $ToDir"

        # Create output dir if needed
        $ToDir = CreateDirectory -Path $ToDir

        if ($Dir.Name -ieq 'Content')
        {
            # Content dirs have binary files that must be duplicated exactly;
            # we cannot rewrite names here
            foreach ($File in Get-ChildItem -Path $Dir -Recurse -File)
            {
                CopyUnrealAsset -FromFile:$File -FromContentRoot:$Dir -ToContentRoot:$ToDir
            }
        }
        elseif ($Dir.Name -ieq 'Plugins')
        {
            foreach ($PluginDir in Get-ChildItem -Path $Dir -Directory)
            {
                if (    ($PluginDir.Name -ieq 'GameFeatures') `
                    -or ($PluginDir.Name -ieq 'Developer') `
                )
                {
                    # GameFeatures and Developer plugins are special
                    $ToSpecialPluginsDir = Join-Path $ToDir $PluginDir.Name
                    foreach ($SubPluginDir in Get-ChildItem -Path $PluginDir -Directory)
                    {
                        # The specific Plugins dir for this plugin the To module
                        $TempTo = Join-Path $ToSpecialPluginsDir $SubPluginDir.Name
                        DuplicateUnrealModule -FromModule $SubPluginDir.FullName -ToModule $TempTo
                    }
                }
                else
                {
                    # Every other type of plugin is like this:
                    # The specific Plugins dir for this plugin the To module
                    $TempTo = Join-Path $ToDir $PluginDir.Name
                    DuplicateUnrealModule -FromModule $PluginDir.FullName -ToModule $TempTo
                }
            }
        }
        else
        {
            # Any other type of directory is a source directory, names and content
            # needs to be refactored for the new project

            foreach ($File in Get-ChildItem -Path $Dir -Recurse -File)
            {
                DuplicateSourceFile -FromFile:$File -FromContentRoot:$Dir -ToDir:$ToDir -KeepRelativity
            }
        }
    }

    Write-Debug "#<<< Duplicate Unreal Module: $ToModule"
}


################################################################################
##  Main Init
################################################################################

# Collect info about From project

$FromDirName = $FromUProjectFile.BaseName
$FromRoot = Get-Item -Path $FromUProjectFile.Directory

# Collect info about To project

$ToDirName = Split-Path $To -Leaf  # Get the leaf name (the directory name itself)
$ToRoot = Get-Item -Path $To 2> $null  # try to get absolute path from existing directory (if any)

if (!$ToRoot)
{
    # No existing directory (we actually expect this) so interpret "To" location in current dir
    if ([System.IO.Path]::IsPathRooted($To))
    {
        # $To is an absolute path
        $ToRoot = $To
    }
    else
    {
        # To is a relative path, prepend current directory to it
        $ToRoot = Join-Path (Get-Location) $To
    }
}


################################################################################
##  Main
################################################################################

Write-Debug "Refactoring Project [$FromDirName] to [$ToDirName]"

try
{
    # Reset/Initialize $CoreRedirects hash table
    $CoreRedirects = @{}

    DuplicateUnrealModule -FromModule $FromRoot -ToModule $ToRoot

    WriteCoreRedirects -ToIni (Join-Path $ToRoot "Config" "DefaultEngine.ini")
}
catch
{
    # On any exception, clean up the output directory that we've been creating,
    # which is in an unknown error state that we don't wish to keep.
    if ($ToItem -and (Test-Path -Path $ToItem.FullName))
    {
        Write-Information "Cleaning up generated files..."
        Remove-Item -Path $ToItem.FullName -Force -Recurse
    }
    # Rethrow for caller
    throw
}

return Get-ChildItem -Path $ToItem.FullName
