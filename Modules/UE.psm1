#
# UE.psm1
#

# Import INI.psm1 (required on Linux+Mac at least)
Import-Module -Name $PSScriptRoot/INI.psm1

# On Mac, custom engine information is stored in this INI file:
$MacInstallIni = "~/Library/Application Support/Epic/UnrealEngine/Install.ini"

# On Windows, custom engine information is stored in the registry here:
$WindowsBuildsRegistryKey = "HKEY_CURRENT_USER\Software\Epic Games\Unreal Engine\Builds"

function UE_GetEngineConfig
{
    [CmdletBinding()]
    param(
        [string]$BuildConfig = "Development",

        [Parameter(Mandatory=$true)]
        [string]$EngineDir
    )

    $scriptExtension = ".bat"
    $exeExtension = ".exe"
    $platform = "Win64"

    if ($IsLinux)
    {
        $scriptExtension = ".sh"
        $exeExtension = ""
        $platform = "Linux"
    }

    if ($IsMacOS)
    {
        $scriptExtension = ".sh"
        $exeExtension = ""
        $platform = "Mac"
    }

    $batchFilesDir = Join-Path $EngineDir "Build" "BatchFiles"
    $binariesDir = Join-Path $EngineDir "Binaries" $platform

    $editorExePrefix = "UnrealEditor"

    if ($BuildConfig -ne "Development")
    {
        $editorExePrefix = "UnrealEditor-$platform-$BuildConfig"
    }

    $editorExeName = "$editorExePrefix$exeExtension"
    $editorCmdExeName = "$editorExePrefix-Cmd$exeExtension"

    $Binaries = [PSCustomObject]@{
        # Full paths to binaries:
        Editor = Join-Path $binariesDir $editorExeName
        EditorCmd = Join-Path $binariesDir $editorCmdExeName

        # Just the BaseName part of the paths to binaries: (Mac requires this)
        EditorName = $editorExeName
        EditorCmdName = $editorCmdExeName
    }

    $Directories = [PSCustomObject]@{
        BatchFiles = $batchFilesDir  # Engine/Build/BatchFiles
        Binaries = $binariesDir  # Engine/Binaries/<Platform>
        Engine = $EngineDir  # Engine
    }

    $Extensions = [PSCustomObject]@{
        Script = $scriptExtension
        Exe = $exeExtension
    }

    $result = [PSCustomObject]@{
        Binaries = $Binaries
        Dirs = $Directories
        Extensions = $Extensions
        Platform = $platform
        UAT = Join-Path $batchFilesDir "RunUAT$scriptExtension"
        UBT = Join-Path $batchFilesDir "RunUBT$scriptExtension"
    }

    return $result
}

function UE_GetEngineByAssociation
{
    [CmdletBinding()]
    param(
        [string]$UProjectFile,
        [string]$EngineAssociation
    )

    $result = [PSCustomObject]@{
        Name = $EngineAssociation  # possibly "" which we may update below
        Root = $null
    }

    # When the $EngineAssociation is empty, it means this uproject is located in a sibling
    # directory to a custom ../Engine directory, thus we want to know the parent directory.
    if (!$EngineAssociation)
    {
        # In this case the $UProjectFile parameter is *required* since we need to use it
        # to determine where the ../ dir is.
        if (!$UProjectFile -or !(Test-Path $UProjectFile))
        {
            throw "Invalid UProjectFile `"$UProjectFile`"; you must give a valid one with an empty EngineAssociation"
        }

        # Compute the path to the .uproject's ../ dir, in which the Engine dir is expected to reside
        # $UProjectFile                                                # /path/to/Project/Project.uproject
        $uProjectDir = Split-Path -Path $UProjectFile -Parent          # /path/to/Project
        $engineRootDir = Split-Path -Path $uProjectDir -Parent         # /path/to

        $result.Root = $engineRootDir

        # We've determined the Engine Root, we need to look up the real name of the Engine
        # on this system (it's not really "" which is what the .uproject states).
        # Try to select the engine by its root dir, and if we find one, use its values.
        $registeredEngine =& UE_SelectCustomEngine -Root $engineRootDir
        if ($registeredEngine)
        {
            $result = $registeredEngine
        }
        else
        {
            # This is likely an unregistered custom engine root with no name.
            # Theoretically it should register itself the first time you actually run it.
            $result.Name = $null
        }

        return $result
    }

    # When $EngineAssociation is NOT empty, it means this is registered to a custom engine
    # or an Epic Games Launcher engine.

    $result =& UE_SelectCustomEngine -Name $EngineAssociation
    if ($result)
    {
        return $result
    }

    Write-Error "No custom engine found matching EngineAssociation `"$EngineAssociation`""
    throw "Not implemented: Obtain default Launcher-installed engine location in UE_GetEngineByAssociation"
}

function UE_ListCustomEngines_Mac
{
    [CmdletBinding()]
    param()

    $result = [System.Collections.ArrayList]@()

    $installationPairs =& INI_ReadSection -Filename $MacInstallIni -Section "Installations"

    if ($installationPairs -and $installationPairs.Count -gt 0)
    {
        for ($i = 0; $i -lt $installationPairs.Count; $i++)
        {
            $iniPair = $installationPairs[$i]
            $result += [PSCustomObject]@{
                Name = $iniPair.Name
                Root = $iniPair.Value
            }
        }
    }

    return $result
}

function UE_ListCustomEngines_Windows
{
    [CmdletBinding()]
    param()

    Write-Debug "Reading custom engines from Registry::$WindowsBuildsRegistryKey"

    $registryBuilds = Get-Item -Path "Registry::$WindowsBuildsRegistryKey" 2> $null
    $result = [System.Collections.ArrayList]@()

    if (!$registryBuilds)
    {
        Write-Warning "Build Registry Not Found: $WindowsBuildsRegistryKey"
        return $result
    }

    # Must iterate to Length; registry key does not have a Count
    for ($i = 0; $i -lt $registryBuilds.Length; $i++)
    {
        $propertyList = $registryBuilds[$i].Property

        # propertyList is an actual array, it has a Count
        if ($propertyList -and $propertyList.Count -gt 0)
        {
            for ($p = 0; $p -lt $propertyList.Count; $p++)
            {
                $buildName = $propertyList[$p]
                if ($buildName)
                {
                    # Get the ItemPropertyValue for this $buildName
                    $value = Get-ItemPropertyValue -Path "Registry::$WindowsBuildsRegistryKey" -Name $buildName

                    # Append the build to the $result array
                    $result += [PSCustomObject]@{
                        Name = $buildName
                        Root = $value
                    }
                }
            }
        }
    }

    return $result
}

function UE_ListCustomEngines
{
    [CmdletBinding()]
    param()

    if ($IsLinux)
    {
        # TODO implement UE_ListCustomEngines for Linux
        throw "Not implemented: UE_ListCustomEngines on Linux"
    }

    if ($IsMacOS)
    {
        return & UE_ListCustomEngines_Mac
    }

    return & UE_ListCustomEngines_Windows
}

function UE_RenameCustomEngine
{
    [CmdletBinding()]
    param(
        [string]$OldName,
        [string]$NewName
    )

    if (!$OldName)
    {
        throw "OldName parameter is required for UE_RenameCustomEngine"
    }

    if (!$NewName)
    {
        throw "NewName parameter is required for UE_RenameCustomEngine"
    }

    if ($IsLinux)
    {
        throw "Not implemented: UE_RenameCustomEngine on Linux"
    }

    if ($IsMacOS)
    {
        # Read the current INI to get the current [Installations] Name=Value pairs
        $installationPairs =& INI_ReadSection -Filename $MacInstallIni -Section "Installations"

        if ($installationPairs)
        {
            Write-Debug "Read $($installationPairs.Count) custom engines from INI"

            # Iterate each of the existing custom engine installation pairs
            for ($i = 0; $i -lt $installationPairs.Count; $i++)
            {
                # If the existing name of the custom engine matches $OldName
                if ($installationPairs[$i].Name -eq $OldName)
                {
                    # Then we want to rename it to $NewName
                    $installationPairs[$i].Name = $NewName

                    Write-Debug "($i) Renamed `"$OldName`" custom engine to `"$NewName`""
                }
            }

            # Rewrite the INI with the new [Installations] Name=Value pairs
            Write-Debug "Writing $($installationPairs.Count) custom engines to INI"
            $success =& INI_WriteSection -Filename $MacInstallIni -Section "Installations" -Pairs $installationPairs
        }
    }

    if ($IsWindows)
    {
        Write-Debug "Renaming registry property `"$OldName`" to `"$NewName`""
        Rename-ItemProperty -Path "Registry::$WindowsBuildsRegistryKey" -Name $OldName -NewName $NewName
    }

    return & UE_SelectCustomEngine -Name $NewName
}

function UE_SelectCustomEngine
{
    [CmdletBinding()]
    param(
        [string]$Name,
        [string]$Root
    )

    if ($Root)
    {
        $RootItem = Get-Item -Path $Root 2> $null
        if ($RootItem -and $RootItem.PSIsContainer)
        {
            # Ensure $Root is the absolute path to the directory, which is what will be stored in the registry
            $Root = $RootItem.FullName
        }
        else
        {
            Write-Warning "Invalid -Root value `"$Root`" is not a valid directory"
            $Root = $null
        }
    }

    if (!$Name -and !$Root)
    {
        Write-Warning "Empty -Name and Empty -Root is not a valid engine query, returning null"
        return $null
    }

    # List all available custom engines
    $customEngines =& UE_ListCustomEngines

    foreach ($engine in $customEngines)
    {
        if ($Name)
        {
            Write-Debug "Compare desired -Name `"$Name`" with `"$($engine.Name)`""
            if ($engine.Name -eq $Name)
            {
                Write-Debug "Found custom engine match on -Name `"$Name`""
                return $engine
            }
        }

        if ($Root)
        {
            # We want to search by root dir.
            # The registry might keep the Root in a non-standard format (e.g. on Windows "D:/Dir" instead of "D:\Dir")
            # Here we get the actual FullName of the directory for the sake of comparison.
            $engineRootItem = Get-Item -Path $engine.Root 2> $null
            if ($engineRootItem -and $engineRootItem.PSIsContainer)
            {
                Write-Debug "Compare desired -Root `"$Root`" with `"$($engineRootItem.FullName)`""
                if ($engineRootItem.FullName -eq $Root)
                {
                    Write-Debug "Found custom engine match on -Root `"$Root`""
                    return $engine
                }
            }
        }
    }

    Write-Warning "Query for Custom Engine (-Name `"$Name`") or (-Root `"$Root`") failed to find a match"
    return $null
}

Export-ModuleMember -Function UE_GetEngineConfig
Export-ModuleMember -Function UE_GetEngineByAssociation, UE_ListCustomEngines, UE_SelectCustomEngine
Export-ModuleMember -Function UE_RenameCustomEngine
