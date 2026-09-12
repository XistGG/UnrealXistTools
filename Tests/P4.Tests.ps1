BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../Modules/P4.psm1') -Force -ErrorAction Stop
}

Describe 'P4.psm1' {
    # No test may fall through to a real Perforce client/server.
    BeforeEach {
        Mock Invoke-P4 { throw 'Unexpected Invoke-P4 call' } -ModuleName P4
    }

    Context 'Path Handling' {
        It 'encodes and decodes reserved characters' {
            $original = 'My/Path/With space/And#Hash/And%Percent/And*Star/And@At/And:Colon'
            $encoded = P4_EncodePath $original
            $encoded | Should -Be 'My/Path/With space/And%23Hash/And%25Percent/And%2AStar/And%40At/And%3AColon'
            P4_DecodePath $encoded | Should -Be $original
        }
    }

    Context 'Change Parsing' {
        It 'P4_ParseChangeLine parses file lines' {
            $result = P4_ParseChangeLine '//depot/file.txt#3 - edit change 123 (text)'
            $result.IsFile | Should -BeTrue
            $result.P4Path | Should -Be '//depot/file.txt'
            $result.Revision | Should -Be '3'
            $result.Info | Should -Be 'edit change 123 (text)'
        }

        It 'P4_ParseChangeLine parses the optional file type' {
            $result = P4_ParseChangeLine '//depot/file.txt#3 - edit change 123 (text+w)' -ParseFileType
            $result.FileType.BaseType | Should -Be 'text'
            $result.FileType.Modifiers.w | Should -BeTrue
        }

        It 'P4_ParseSpecification parses simple specs' {
            $content = @('Key: Value', 'Description:', "`tMy Description", "`tMore lines")
            $result = P4_ParseSpecification -Content $content
            $result.Key | Should -Be 'Value'
            $result.Description[0] | Should -Be 'My Description'
            $result.Description[1] | Should -Be 'More lines'
        }

        It 'P4_ParseChangeDescription parses p4 describe -s output' {
            # This parser is private; enter its module only at test runtime.
            InModuleScope P4 {
                $content = @(
                    'Change 12345 by user@client on 2024/01/01 12:00:00'
                    ''
                    "`tMy Change Description"
                    "`tLine 2"
                    ''
                    'Affected files ...'
                    ''
                    '... //depot/file1.txt#1 add'
                    '... //depot/file2.txt#2 edit'
                )
                $result = P4_ParseChangeDescription -Content $content
                $result.Change | Should -Be '12345'
                $result.User | Should -Be 'user'
                $result.Client | Should -Be 'client'
                $result.Description | Should -Be ("My Change Description" + [Environment]::NewLine + 'Line 2')
                $result.Files.Count | Should -Be 2
                $result.Files[0].Path | Should -Be '//depot/file1.txt'
                $result.Files[0].ChangeType | Should -Be 'add'
            }
        }
    }

    Context 'P4 Wrappers (Mocked Invoke-P4)' {
        It 'P4_GetPendingChangeLists parses output' {
            Mock Invoke-P4 {
                "Change 123 on 2024/01/01 by user@ws *pending* 'Desc'"
            } -ModuleName P4 -ParameterFilter { ($Arguments -join '|') -eq 'changes|-c|ws|-s|pending|-r' }

            $result = @(P4_GetPendingChangeLists -Workspace 'ws')
            $result.Count | Should -Be 1
            $result[0] | Should -Be '123'
            Should -Invoke Invoke-P4 -ModuleName P4 -Times 1 -Exactly -Scope It
        }

        It 'P4_FStat passes each encoded path separately and parses output' {
            Mock Invoke-P4 {
                @(
                    '... depotFile //depot/file%23one with spaces.txt'
                    '... headRev 1'
                    ''
                    '... depotFile //depot/file%40two with spaces.txt'
                    '... headRev 2'
                    ''
                )
            } -ModuleName P4 -ParameterFilter {
                $Arguments.Count -eq 3 -and $Arguments[0] -eq 'fstat' -and
                $Arguments[1] -eq '//depot/file%23one with spaces.txt' -and
                $Arguments[2] -eq '//depot/file%40two with spaces.txt'
            }

            $paths = [System.Collections.ArrayList]@('//depot/file#one with spaces.txt', '//depot/file@two with spaces.txt')
            $result = @(P4_FStat -Paths $paths)
            $result.Count | Should -Be 2
            $result[0].depotFile | Should -Be $paths[0]
            $result[1].depotFile | Should -Be $paths[1]
            Should -Invoke Invoke-P4 -ModuleName P4 -Times 1 -Exactly -Scope It
        }

        It 'P4_FStat preserves a final record without a trailing blank line' {
            Mock Invoke-P4 {
                @('... depotFile //depot/file.txt', '... headRev 1')
            } -ModuleName P4 -ParameterFilter { $Arguments[0] -eq 'fstat' }

            $result = @(P4_FStat -Paths ([System.Collections.ArrayList]@('//depot/file.txt')))
            $result.Count | Should -Be 1
            $result[0].headRev | Should -Be '1'
        }

        It 'P4_FStat ignores repeated blank separators' {
            Mock Invoke-P4 {
                @('', '... depotFile //depot/file.txt', '... headRev 1', '', '')
            } -ModuleName P4 -ParameterFilter { $Arguments[0] -eq 'fstat' }

            $result = @(P4_FStat -Paths ([System.Collections.ArrayList]@('//depot/file.txt')))
            $result.Count | Should -Be 1
            $result[0].depotFile | Should -Be '//depot/file.txt'
        }

        It 'P4_GetChange omits an unspecified changelist argument' {
            Mock Invoke-P4 {
                @('Change: new', 'Description:', "`t<enter description here>")
            } -ModuleName P4 -ParameterFilter { ($Arguments -join '|') -eq 'change|-o' }

            (P4_GetChange).Change | Should -Be 'new'
            Should -Invoke Invoke-P4 -ModuleName P4 -Times 1 -Exactly -Scope It
        }

        It 'P4_GetChange handles <Label> changelists' -ForEach @(
            @{ Label = 'null'; CL = $null; ExpectedArguments = 'change|-o'; Change = 'new' }
            @{ Label = 'empty'; CL = ''; ExpectedArguments = 'change|-o'; Change = 'new' }
            @{ Label = 'default'; CL = 'default'; ExpectedArguments = 'change|-o'; Change = 'new' }
            @{ Label = 'numbered'; CL = '123'; ExpectedArguments = 'change|-o|123'; Change = '123' }
        ) {
            Mock Invoke-P4 {
                @("Change: $Change", 'Description:', "`tDescription")
            } -ModuleName P4 -ParameterFilter { ($Arguments -join '|') -eq $ExpectedArguments }

            (P4_GetChange -CL $CL).Change | Should -Be $Change
            Should -Invoke Invoke-P4 -ModuleName P4 -Times 1 -Exactly -Scope It
        }

        It 'P4_Describe returns parsed description' {
            Mock Invoke-P4 {
                @('Change 123 by user@client on 2024/01/01 12:00:00', '', "`tDesc", '', 'Affected files ...')
            } -ModuleName P4 -ParameterFilter { ($Arguments -join '|') -eq 'describe|-s|123' }

            $result = P4_Describe -CL '123'
            $result.Change | Should -Be '123'
            $result.Description | Should -Be 'Desc'
            Should -Invoke Invoke-P4 -ModuleName P4 -Times 1 -Exactly -Scope It
        }

        It 'P4_FilterIgnoredPaths separates ignored and valid paths with spaces' {
            $validPath = Join-Path $TestDrive 'valid file.txt'
            $ignoredPath = Join-Path $TestDrive 'ignored file.txt'
            Mock Invoke-P4 { "$ignoredPath ignored" } -ModuleName P4 -ParameterFilter {
                $Arguments.Count -eq 4 -and $Arguments[0] -eq 'ignores' -and $Arguments[1] -eq '-i' -and
                $Arguments[2] -eq $validPath -and $Arguments[3] -eq $ignoredPath
            }

            $paths = [System.Collections.ArrayList]@($validPath, $ignoredPath)
            $result = P4_FilterIgnoredPaths -Paths $paths
            $result.ValidPaths.Count | Should -Be 1
            $result.ValidPaths[0] | Should -Be $validPath
            $result.IgnoredPaths.Count | Should -Be 1
            $result.IgnoredPaths[0] | Should -Be $ignoredPath
            Should -Invoke Invoke-P4 -ModuleName P4 -Times 1 -Exactly -Scope It
        }

        It 'P4_FilterIgnoredPaths keeps every path when nothing is ignored' {
            Mock Invoke-P4 { @() } -ModuleName P4 -ParameterFilter { $Arguments[0] -eq 'ignores' }
            $paths = [System.Collections.ArrayList]@((Join-Path $TestDrive 'one.txt'), (Join-Path $TestDrive 'two.txt'))
            $result = P4_FilterIgnoredPaths -Paths $paths
            $result.ValidPaths | Should -Be $paths
            $result.IgnoredPaths.Count | Should -Be 0
        }

        It 'P4_StreamInfo returns parsed stream spec' {
            Mock Invoke-P4 { @('Stream: //stream/main', 'Name: main') } -ModuleName P4 -ParameterFilter {
                ($Arguments -join '|') -eq 'stream|-o|//stream/main'
            }

            $result = P4_StreamInfo -Stream '//stream/main'
            $result.Stream | Should -Be '//stream/main'
            $result.Name | Should -Be 'main'
            Should -Invoke Invoke-P4 -ModuleName P4 -Times 1 -Exactly -Scope It
        }
    }
}
