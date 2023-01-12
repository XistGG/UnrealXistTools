# 
# UProjectFile.ps1
#

# Try to get information about the UProject (file or directory)
$UProjectItem = Get-Item -Path $UProjectFile 2> $null

if (!$UProjectItem.Exists)
{
    throw "No such UProject file or directory: $UProjectFile"
}

# First check of $UProjectFile is a file
if (!$UProjectItem.PSIsContainer)
{
    # Expand this file to its absolute path
    $UProjectFile = $UProjectItem.FullName
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
