#!/usr/bin/env pwsh

[CmdletBinding()]
param(
)

# Make sure the powershell version is good, or throw an exception
& $PSScriptRoot/../PSVersionCheck.ps1

# Import the P4 helper module
Import-Module -Name $PSScriptRoot/../Modules/P4.psm1

P4_ParseFileType "text"
P4_ParseFileType "binary"
P4_ParseFileType "utf8"

P4_ParseFileType "text+w"
P4_ParseFileType "binary+w"
P4_ParseFileType "utf8+w"

P4_ParseFileType "text+x"
P4_ParseFileType "binary+x"

P4_ParseFileType "binary+wxlS"
P4_ParseFileType "binary+wxlS16"

P4_ParseFileType "text+x"
P4_ParseFileType "text+wx"
P4_ParseFileType "text+kwx"
P4_ParseFileType "text+kowx"
P4_ParseFileType "text+kowxml"
P4_ParseFileType "text+kowxmlS"
P4_ParseFileType "text+kowxmlS16"

Write-Host "EXPECT to get a warning about `"zy`" being invalid here:"
P4_ParseFileType "text+S2zxyko"  # expect warning for "zy"

Write-Host
