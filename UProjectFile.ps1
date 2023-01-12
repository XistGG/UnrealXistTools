# 
# UProjectFile.ps1
#
# See: https://github.com/XistGG/UnrealXistTools/
#
# This is an include file.  It takes an optionally set
# $UProjectFile value and expands it to an actual MyGame.uproject
# file location.
#
# The value you pass in can be:
#
# (empty) -> '.'
# '../MyGame.uproject'
# '../MyGame' # (same as '../MyGame/MyGame.uproject')
#
# If the passed in value does not expand to a valid uproject file,
# an exception is thrown.
#
# If no exception is thrown, these variables will be set:
#
# $UProjectFile = absolute path to MyGame.uproject
# $UProjectDirectory = absolute path to MyGame.uproject parent directory
#

if ($UProjectFile -eq '')
{
    $UProjectFile = '.'
}

# Try to get information about the UProject (file or directory)
$UProjectItem = Get-Item -Path $UProjectFile 2> $null

if (!$UProjectItem.Exists)
{
    throw "No such UProject file or directory: $UProjectFile"
}

# First check of $UProjectFile is a file
if (!$UProjectItem.PSIsContainer)
{
    if ($UProjectItem.Name -cmatch '\.uproject$')
    {
        # Expand this file to its absolute path
        $UProjectFile = $UProjectItem.FullName
    }
    else
    {
        throw "File is not a UProject: $UProjectFile"
    }
}
else
{
    # $UProjectFile is a directory.

    # Check if it is a directory with a uproject inside it,
    #     like "Foo" => "Foo/Foo.uproject"
    #       or "."   => "Whatever/Whatever.uproject"

    $Name = $UProjectItem.Name
    $File = Join-Path -Path $UProjectItem.FullName -ChildPath "${Name}.uproject"

    $UProjectItem = Get-Item -Path $File 2> $null

    if ($UProjectItem.Exists -and !($UProjectItem.PSIsContainer))
    {
        $UProjectFile = $File
    }
    else
    {
        throw "No such file ${Name}.uproject in directory: $UProjectFile"
    }
}


$UProjectDirectory = $UProjectItem.Directory.FullName


if (!$Quiet)
{
    Write-Host ""
    Write-Host "UProjectFile=$UProjectFile"
    Write-Host "UProjectDir=$UProjectDirectory"
    Write-Host ""
}
