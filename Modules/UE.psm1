#
# UE.psm1
#

Import-Module -Name $PSScriptRoot/INI.psm1 -Force -Verbose

# On Mac, custom engine information is stored in this INI file:
$MacInstallIni = "~/Library/Application Support/Epic/UnrealEngine/Install.ini"

# On Windows, custom engine information is stored in the registry here:
$WindowsBuildsRegistryKey = "HKEY_CURRENT_USER\Software\Epic Games\Unreal Engine\Builds"

function UE_GetEngineConfig
{
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

    $Binaries = [PSCustomObject]@{
        Editor = Join-Path $binariesDir "$editorExePrefix$exeExtension"
        EditorCmd = Join-Path $binariesDir "$editorExePrefix-Cmd$exeExtension"
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
    param(
        [string]$UProjectFile,
        [string]$EngineAssociation
    )

    $result = [PSCustomObject]@{
        Name = $EngineAssociation
        Root = $null
    }

    # When the $EngineAssociation is empty, it means this uproject is located in a sibling
    # directory to a custom ../Engine directory, thus we want to know the parent directory.
    if (!$EngineAssociation -or $EngineAssociation -eq "")
    {
        # In this case the $UProjectFile parameter is *required* since we need to use it
        # to determine where the ../ dir is.
        if (!$UProjectFile -or $UProjectFile -eq "" -or !(Test-Path $UProjectFile))
        {
            throw "Invalid UProjectFile `"$UProjectFile`"; you must give a valid one with an empty EngineAssociation"
        }

        # Compute the path to the .uproject's ../ dir, in which the Engine dir is expected to reside
        # $UProjectFile                                                # /path/to/Project/Project.uproject
        $uProjectDir = Split-Path -Path $UProjectFile -Parent          # /path/to/Project
        $engineRootDir = Split-Path -Path $uProjectDir -Parent         # /path/to

        $result.Root = $engineRootDir
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
    if ($IsLinux)
    {
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
            # Iterate each of the existing custom engine installation pairs
            for ($i = 0; $i -lt $installationPairs.Count; $i++)
            {
                # If the existing name of the custom engine matches $OldName
                if ($installationPairs[$i].Name -eq $OldName)
                {
                    # Then we want to rename it to $NewName
                    $installationPairs[$i].Name = $NewName
                }
            }

            # Rewrite the INI with the new [Installations] Name=Value pairs
            $success =& INI_WriteSection -Filename $MacInstallIni -Section "Installations" -Pairs $installationPairs
        }
    }

    if ($IsWindows)
    {
        Rename-ItemProperty -Path "Registry::$WindowsBuildsRegistryKey" -Name $OldName -NewName $NewName
    }

    return & UE_SelectCustomEngine -Name $NewName
}

function UE_SelectCustomEngine
{
    param(
        [string]$Name
    )

    $customEngines =& UE_ListCustomEngines

    foreach ($engine in $customEngines)
    {
        if ($engine.Name -eq $Name)
        {
            return $engine
        }
    }

    return $null
}

Export-ModuleMember -Function UE_GetEngineConfig, UE_GetEngineByAssociation, UE_ListCustomEngines, UE_RenameCustomEngine, UE_SelectCustomEngine
