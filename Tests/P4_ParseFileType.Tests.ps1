BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../Modules/P4.psm1') -Force -ErrorAction Stop
}

Describe 'P4_ParseFileType' {
    BeforeEach {
        Mock Write-Warning {} -ModuleName P4
    }

    It 'parses <TypeString>' -ForEach @(
        @{ TypeString = 'text'; BaseType = 'text'; ModString = $null; Modifiers = @{} }
        @{ TypeString = 'binary'; BaseType = 'binary'; ModString = $null; Modifiers = @{} }
        @{ TypeString = 'utf8'; BaseType = 'utf8'; ModString = $null; Modifiers = @{} }
        @{ TypeString = 'text+w'; BaseType = 'text'; ModString = 'w'; Modifiers = @{ w = $true } }
        @{ TypeString = 'binary+w'; BaseType = 'binary'; ModString = 'w'; Modifiers = @{ w = $true } }
        @{ TypeString = 'utf8+w'; BaseType = 'utf8'; ModString = 'w'; Modifiers = @{ w = $true } }
        @{ TypeString = 'text+x'; BaseType = 'text'; ModString = 'x'; Modifiers = @{ x = $true } }
        @{ TypeString = 'binary+x'; BaseType = 'binary'; ModString = 'x'; Modifiers = @{ x = $true } }
        @{ TypeString = 'binary+wxlS'; BaseType = 'binary'; ModString = 'wxlS'; Modifiers = @{ w = $true; x = $true; l = $true; S = 1 } }
        @{ TypeString = 'binary+wxlS16'; BaseType = 'binary'; ModString = 'wxlS16'; Modifiers = @{ w = $true; x = $true; l = $true; S = 16 } }
        @{ TypeString = 'text+wx'; BaseType = 'text'; ModString = 'wx'; Modifiers = @{ w = $true; x = $true } }
        @{ TypeString = 'text+kwx'; BaseType = 'text'; ModString = 'kwx'; Modifiers = @{ k = $true; w = $true; x = $true } }
        # ko is one modifier, mutually exclusive with k (not separate k and o flags).
        @{ TypeString = 'text+kowx'; BaseType = 'text'; ModString = 'kowx'; Modifiers = @{ ko = $true; w = $true; x = $true } }
        @{ TypeString = 'text+kowxml'; BaseType = 'text'; ModString = 'kowxml'; Modifiers = @{ ko = $true; w = $true; x = $true; m = $true; l = $true } }
        @{ TypeString = 'text+kowxmlS'; BaseType = 'text'; ModString = 'kowxmlS'; Modifiers = @{ ko = $true; w = $true; x = $true; m = $true; l = $true; S = 1 } }
        @{ TypeString = 'text+kowxmlS16'; BaseType = 'text'; ModString = 'kowxmlS16'; Modifiers = @{ ko = $true; w = $true; x = $true; m = $true; l = $true; S = 16 } }
    ) {
        $result = P4_ParseFileType $TypeString

        $result.RawType | Should -BeExactly $TypeString
        $result.BaseType | Should -BeExactly $BaseType
        $result.ModString | Should -BeExactly $ModString
        # Check the complete set, so spurious modifiers also fail the test.
        @($result.Modifiers.PSObject.Properties).Count | Should -Be $Modifiers.Count
        foreach ($name in $Modifiers.Keys) {
            $result.Modifiers.$name | Should -Be $Modifiers[$name] -Because "$TypeString should parse modifier $name"
        }
        Should -Invoke Write-Warning -ModuleName P4 -Times 0 -Exactly -Scope It
    }

    It 'warns about unrecognized modifiers while preserving recognized ones' {
        $result = P4_ParseFileType 'text+S2zxyko'

        $result.RawType | Should -BeExactly 'text+S2zxyko'
        $result.BaseType | Should -BeExactly 'text'
        $result.ModString | Should -BeExactly 'S2zxyko'
        @($result.Modifiers.PSObject.Properties).Count | Should -Be 3
        $result.Modifiers.S | Should -Be 2
        $result.Modifiers.x | Should -BeTrue
        $result.Modifiers.ko | Should -BeTrue
        Should -Invoke Write-Warning -ModuleName P4 -Times 1 -Exactly -Scope It
        Should -Invoke Write-Warning -ModuleName P4 -Times 1 -Exactly -Scope It -ParameterFilter {
            $Message -like '*unrecognized modifier: "zy"*'
        }
    }
}
