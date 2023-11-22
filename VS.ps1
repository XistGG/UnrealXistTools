#
# VS.ps1
#
# Invoke Visual Studio
#

[CmdletBinding()]
param(
    [Switch]$Diff,
    [Switch]$Test,
    [Parameter(ValueFromRemainingArguments)]$Args
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

# Set $env:VisualStudioPath to override the default value
$VisualStudioPath = $env:VisualStudioPath ? $env:VisualStudioPath :
    "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\devenv.exe"

$ScriptName = $MyInvocation.MyCommand.Name


################################################################################
##  -Diff file1 file2
################################################################################

if ($Diff)
{
    if ($Args.Count -ne 2)
    {
        Write-Error "Usage: $ScriptName -diff file1 file2"
        throw "Invalid argument count: $($Args.Count); expect 2"
    }

    $file1 = $Args[0]
    $file2 = $Args[1]

    Write-Debug "Diff [$file1] with [$file2]"

    if (!$Test)
    {
        & $VisualStudioPath /diff $file1 $file2 "First:$file1" "Second:$file2"
    }
    exit 0;
}

################################################################################
##  Main
################################################################################

# If there is an argument, it's a custom $Path
$Path = $Args.Count ? $Args[0] : $null

Write-Debug "Compute UProjectSln Path=[$Path]"

$UProjectSln =& $PSScriptRoot/UProjectSln.ps1 -Path:$Path

if (!$UProjectSln -or !$UProjectSln.Exists)
{
    throw "Path is not a Solution: [$Path]"
}


# Start Visual Studio for the selected UProjectSln

if (!$Test)
{
    # Locate a .p4config and export it to the system environment before starting Rider
    & $PSScriptRoot/P4Config.ps1 -Export -Path $UProjectSln.Directory.FullName

    & $VisualStudioPath $UProjectSln.FullName
}
