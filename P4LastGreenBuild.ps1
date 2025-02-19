#!/usr/bin/env pwsh
#
# P4LastGreenBuild.ps1
#
#   Show the stream Paths array of the //UE5/Dev-Main-LastGreenBuild stream.
#   This will tell you which CL to sync to in //UE5/Main.
#
#   Example output:
#       import ... //UE5/Main/...@40123400
#
#   Before you run this, you must ensure your $env:P4* vars are correctly
#   configured to connect to UDN P4.
#
#   The purpose of this script is to make it really simple to know where
#   in //UE5/Main the virtual stream //UE5/Dev-Main-LastGreenBuild points.
#   This way you can easily sync your //UE5/Main branch to a CL that is
#   known to at least compile successfully.
#

[CmdletBinding()]
param(
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/PSVersionCheck.ps1

# Import the P4 helper module
Import-Module -Name $PSScriptRoot/Modules/P4.psm1

# Get stream info and return the Paths array
$Info =& P4_StreamInfo -Stream '//UE5/Dev-Main-LastGreenBuild'
return $Info.Paths
