#
# UE.psm1
#

function UE_GetEngineConfig
{
    param(
        [string]$BuildConfig = "Development",

        [Parameter(Mandatory=$true)]
        [string]$EngineDir
    )

    $ScriptExtension = ".bat"
    $ExeExtension = ".exe"
    $Platform = "Win64"

    if ($IsLinux)
    {
        $ScriptExtension = ".sh"
        $ExeExtension = ""
        $Platform = "Linux"
    }

    if ($IsMacOS)
    {
        $ScriptExtension = ".sh"
        $ExeExtension = ""
        $Platform = "Mac"
    }

    $BatchFilesDir = Join-Path $EngineDir "Build" "BatchFiles"
    $BinariesDir = Join-Path $EngineDir "Binaries" $Platform

    $EditorExePrefix = "UnrealEditor"

    if ($BuildConfig -ne "Development")
    {
        $EditorExePrefix = "UnrealEditor-$Platform-$BuildConfig"
    }

    $Binaries = [PSCustomObject]@{
        Editor = Join-Path $BinariesDir "$EditorExePrefix$ExeExtension"
        EditorCmd = Join-Path $BinariesDir "$EditorExePrefix-Cmd$ExeExtension"
    }

    $Directories = [PSCustomObject]@{
        BatchFiles = $BatchFilesDir  # Engine/Build/BatchFiles
        Binaries = $BinariesDir  # Engine/Binaries/<Platform>
        Engine = $EngineDir  # Engine
    }

    $Extensions = [PSCustomObject]@{
        script = $ScriptExtension
        exe = $ExeExtension
    }

    $Result = [PSCustomObject]@{
        Binaries = $Binaries
        Dirs = $Directories
        Extensions = $Extensions
        Platform = $Platform
        UAT = Join-Path $BatchFilesDir "RunUAT$ScriptExtension"
        UBT = Join-Path $BatchFilesDir "RunUBT$ScriptExtension"
    }

    return $Result
}

function UE_GetEngineByAssociation
{
    param(
        [string]$UProjectFile,
        [string]$EngineAssociation
    )

    $Result = [PSCustomObject]@{
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
        $UProjectDir = Split-Path -Path $UProjectFile -Parent          # /path/to/Project
        $EngineRootDir = Split-Path -Path $UProjectDir -Parent         # /path/to

        $Result.Root = $EngineRootDir
        return $Result
    }

    # When $EngineAssociation is NOT empty, it means this is registered to a custom engine
    # or an Epic Games Launcher engine.
    #
    # TODO try to get info on the Engine named $EngineAssociation
    # It could be like "5.3" or "5.4" (likely an official Launcher-installed Engine)
    #          or like "CustomEngineName" (in Windows Registry or who knows in Linux/Mac)
    #
    # For now this just isn't implemented.

    throw "Not implemented: Cannot locate Engines for UProjects living outside a Custom Engine root"
}

Export-ModuleMember -Function UE_GetEngineConfig, UE_GetEngineByAssociation
