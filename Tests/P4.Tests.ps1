$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = Join-Path (Split-Path -Parent $here) "Modules\P4.psm1"
Import-Module $sut -Force

InModuleScope P4 {

    Describe "P4.psm1" {

        Context "Path Handling" {
            It "P4_DecodePath encodes/decodes correctly" {
                $original = "My/Path/With space/And#Hash/And%Percent/And*Star/And@At/And:Colon"
                $encoded = P4_EncodePath $original
                $decoded = P4_DecodePath $encoded
                
                $encoded | Should Be "My/Path/With space/And%23Hash/And%25Percent/And%2AStar/And%40At/And%3AColon"
                $decoded | Should Be $original
            }
        }

        Context "File Types" {
            It "parses basic types" {
                $r = P4_ParseFileType "text"
                $r.BaseType | Should Be "text"
                $r.ModString | Should BeNullOrEmpty
                
                $r = P4_ParseFileType "binary"
                $r.BaseType | Should Be "binary"
            }

            It "parses types with modifiers" {
                $r = P4_ParseFileType "text+w"
                $r.BaseType | Should Be "text"
                $r.Modifiers.w | Should Be $true

                $r = P4_ParseFileType "binary+wxlS"
                $r.BaseType | Should Be "binary"
                $r.Modifiers.w | Should Be $true
                $r.Modifiers.x | Should Be $true
                $r.Modifiers.l | Should Be $true
                $r.Modifiers.S | Should Be 1
            }

            It "parses modifiers with arguments" {
                $r = P4_ParseFileType "binary+wxlS16"
                $r.Modifiers.S | Should Be 16
            }
            
            It "parses complex combinations" {
                $r = P4_ParseFileType "text+kowxml"
                $r.Modifiers.k | Should Be $true
                $r.Modifiers.o | Should Be $true
                $r.Modifiers.w | Should Be $true
                $r.Modifiers.x | Should Be $true
                $r.Modifiers.m | Should Be $true
                $r.Modifiers.l | Should Be $true
            }

            It "warns on invalid modifiers" {
                Mock Write-Warning {}
                $r = P4_ParseFileType "text+S2zxyko"
                Assert-MockCalled Write-Warning
            }
        }
        
        Context "Change Parsing" {
            It "P4_ParseChangeLine parses file lines" {
                $line = "//depot/file.txt#3 - edit change 123 (text)"
                $result = P4_ParseChangeLine $line
                
                $result.IsFile | Should Be $true
                $result.P4Path | Should Be "//depot/file.txt"
                $result.Revision | Should Be "3"
                $result.Info | Should Be "edit change 123 (text)"
            }
            
            It "P4_ParseChangeLine with ParseFileType" {
                $line = "//depot/file.txt#3 - edit change 123 (text+w)"
                $result = P4_ParseChangeLine $line -ParseFileType
                 
                $result.FileType.BaseType | Should Be "text"
                $result.FileType.Modifiers.w | Should Be $true
            }

            It "P4_ParseSpecification parses simple specs" {
                $content = @(
                    "Key: Value",
                    "Description:",
                    "	My Description",
                    "	More lines"
                )
                $result = P4_ParseSpecification -Content $content
                $result.Key | Should Be "Value"
                $result.Description[0] | Should Be "My Description"
                $result.Description[1] | Should Be "More lines"
            }
            
            It "P4_ParseChangeDescription parses p4 describe -s output" {
                $content = @(
                    "Change 12345 by user@client on 2024/01/01 12:00:00",
                    "",
                    "	My Change Description",
                    "	Line 2",
                    "",
                    "Affected files ...",
                    "",
                    "... //depot/file1.txt#1 add",
                    "... //depot/file2.txt#2 edit"
                )
                 
                $result = P4_ParseChangeDescription -Content $content
                $result.Change | Should Be "12345"
                $result.User | Should Be "user"
                $result.Client | Should Be "client"
                $result.Files.Count | Should Be 2
                $result.Files[0].Path | Should Be "//depot/file1.txt"
                $result.Files[0].ChangeType | Should Be "add"
            }
        }

        Context "P4 Wrappers (Mocked Invoke-P4)" {
            
            # Using specific parameter filters for Mock to ensure correct calls are being made
            
            It "P4_GetPendingChangeLists parses output" {
                Mock Invoke-P4 {
                    param($Arguments)
                    return "Change 123 on 2024/01/01 by user@ws *pending* 'Desc'"
                } -ParameterFilter { 
                    $Arguments[0] -eq "changes" -and 
                    $Arguments[1] -eq "-c" -and 
                    $Arguments[3] -eq "-s" -and 
                    $Arguments[4] -eq "pending" 
                }
                
                $result = P4_GetPendingChangeLists -Workspace "ws"
                $result.Count | Should Be 1
                $result[0] | Should Be "123"
            }
            
            It "P4_FStat parses output" {
                Mock Invoke-P4 {
                    param($Arguments)
                    return @(
                        "... depotFile //depot/file.txt",
                        "... headRev 1",
                        "",
                        "... depotFile //depot/file2.txt",
                        "... headRev 2",
                        ""
                    )
                } -ParameterFilter { $Arguments[0] -eq "fstat" }
                 
                $paths = [System.Collections.ArrayList]@("//depot/file.txt", "//depot/file2.txt")
                $result = P4_FStat -Paths $paths
                 
                $result.Count | Should Be 2
                $result[0].depotFile | Should Be "//depot/file.txt"
            }
            
            It "P4_GetChange returns parsed spec" {
                Mock Invoke-P4 {
                    param($Arguments)
                    return @(
                        "Change: new",
                        "Description:",
                        "	<enter description here>"
                    )
                } -ParameterFilter { $Arguments[0] -eq "change" }
                 
                $result = P4_GetChange
                $result.Change | Should Be "new"
            }
            
            It "P4_Describe returns parsed description" {
                Mock Invoke-P4 {
                    param($Arguments)
                    return @(
                        "Change 123 by user@client on 2024/01/01 12:00:00",
                        "",
                        "	Desc",
                        "Affected files ..."
                    )
                } -ParameterFilter { $Arguments[0] -eq "describe" -and $Arguments[2] -eq "123" }
                 
                $result = P4_Describe -CL "123"
                $result.Change | Should Be "123"
            }
            
            It "P4_FilterIgnoredPaths separates ignored and valid paths" {
                Mock Invoke-P4 { 
                    param($Arguments)
                    # Return ignored file output
                    return "c:\ignored.txt ignored" 
                } -ParameterFilter { $Arguments[0] -eq "ignores" -and $Arguments[1] -eq "-i" }
                
                $paths = [System.Collections.ArrayList]@("c:\valid.txt", "c:\ignored.txt")
                $result = P4_FilterIgnoredPaths -Paths $paths
                
                $result.ValidPaths.Count | Should Be 1
                $result.ValidPaths[0] | Should Be "c:\valid.txt"
                $result.IgnoredPaths.Count | Should Be 1
                $result.IgnoredPaths[0] | Should Be "c:\ignored.txt"
            }
            
            It "P4_StreamInfo returns parsed stream spec" {
                Mock Invoke-P4 {
                    param($Arguments)
                    return @(
                        "Stream: //stream/main",
                        "Name: main"
                    )
                } -ParameterFilter { $Arguments[0] -eq "stream" }
                 
                $result = P4_StreamInfo -Stream "//stream/main"
                $result.Stream | Should Be "//stream/main"
                $result.Name | Should Be "main"
            }
        }
    }
}
