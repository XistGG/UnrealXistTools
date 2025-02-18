#!/usr/bin/env pwsh
#
# P4RemergeLyraExample.ps1
#
#   This is an example of a script you can make yourself to re-merge a Lyra side-stream
#   into your own Lyra project.
#
#   In this example I define some translation rules:
#
#     - My project = Xim.uproject (from Lyra.uproject)
#     - My Target.cs files are all XimFoo.Target.cs (from LyraFoo.Target.cs)
#     - I do not use any default Lyra GameFeaturePlugins
#
#   Here "//XE/Lyra-Xist" is the same as "//Lyra/Xist" from my Perforce docs:
#   @see https://x157.github.io/Perforce/
#
#   If you derived your game directly from that stream, you don't need to use this script.
#   However I have some Lyra projects that live inside other custom engine depots, where
#   there is no Lyra stream as a direct ancestor, and so this script performs side-merges
#   to get updated Lyra contents into those projects.
#

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string] $CL,

    [switch] $Force
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

$TranslationRules = [ordered] @{}

$TranslationRules['^Lyra\.uproject$'] = 'Xim.uproject'  # Xim project name
$TranslationRules['^Source/Lyra(.*\.Target\.cs)$'] = 'Source/Xim$1'  # Xim target names
$TranslationRules['^Plugins/GameFeatures/.*'] = ''  # IGNORE all default Lyra GameFeaturePlugins

& $PSScriptRoot/P4RemergeSidestream.ps1 `
    -CL:$CL -Force:$Force `
    -SourceDepot "//XE/Lyra-Xist" `
    -SourceDir "D:/Dev/Lyra-Xist" `
    -LocalDir "D:/Dev/XimMain/Xim" `
    -TranslationRules:$TranslationRules
