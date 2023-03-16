#
# VS.ps1
#
# Open Visual Studio for the given Sln
#

[CmdletBinding()]
param(
    [Parameter()]$Path
)


# Set $env:VisualStudioPath to override the default value
$VisualStudioPath = $env:VisualStudioPath ? $env:VisualStudioPath :
    "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\devenv.exe"


################################################################################
##  Main
################################################################################

# Require a valid $UProjectSln

Write-Debug "Compute UProjectSln Path=[$Path]"

$UProjectSln =& $PSScriptRoot/UProjectSln.ps1 -Path:$Path

if (!$UProjectSln -or !$UProjectSln.Exists)
{
    throw "Path is not a Solution: $Path"
}


# Start Visual Studio for the selected UProjectSln

& $VisualStudioPath $UProjectSln.FullName
