$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = Join-Path (Split-Path -Parent $here) "Modules\INI.psm1"
Import-Module $sut -Force

Describe "INI.psm1" {

    Context "INI_ReadSection" {
        It "returns null if file does not exist and MayNotExist is set" {
            Mock Test-Path { return $false } -ModuleName INI
            $result = INI_ReadSection -Filename "fake.ini" -Section "Any" -MayNotExist
            $result | Should BeNullOrEmpty
        }

        It "warns and returns null if file does not exist and MayNotExist is NOT set" {
            Mock Test-Path { return $false } -ModuleName INI
            Mock Write-Warning {} -ModuleName INI
            $result = INI_ReadSection -Filename "fake.ini" -Section "Any"
            $result | Should BeNullOrEmpty
            Assert-MockCalled Write-Warning -ModuleName INI
        }

        It "reads a simple section correctly" {
            Mock Test-Path { return $true } -ModuleName INI
            Mock Get-Content { return @(
                    "[Section1]",
                    "Key1=Value1",
                    "Key2=Value2"
                ) } -ModuleName INI

            $result = INI_ReadSection -Filename "fake.ini" -Section "Section1"
            $result.Count | Should Be 2
            $result[0].Name | Should Be "Key1"
            $result[0].Value | Should Be "Value1"
            $result[1].Name | Should Be "Key2"
            $result[1].Value | Should Be "Value2"
        }

        It "ignores comments and empty lines" {
            Mock Test-Path { return $true } -ModuleName INI
            Mock Get-Content { return @(
                    "[TargetSection]",
                    "",
                    "; This is a comment",
                    "RealKey=RealValue",
                    "   ; indented comment",
                    "   "
                ) } -ModuleName INI

            $result = INI_ReadSection -Filename "fake.ini" -Section "TargetSection"
            $result.Count | Should Be 1
            $result[0].Name | Should Be "RealKey"
            $result[0].Value | Should Be "RealValue"
        }

        It "ignores other sections" {
            Mock Test-Path { return $true } -ModuleName INI
            Mock Get-Content { return @(
                    "[OtherSection]",
                    "Key=BadValue",
                    "[TargetSection]",
                    "Key=GoodValue",
                    "[AnotherSection]",
                    "Key=BadValue"
                ) } -ModuleName INI

            $result = INI_ReadSection -Filename "fake.ini" -Section "TargetSection"
            $result.Count | Should Be 1
            $result[0].Value | Should Be "GoodValue"
        }

        It "handles whitespace around keys and values" {
            Mock Test-Path { return $true } -ModuleName INI
            Mock Get-Content { return @(
                    "[TargetSection]",
                    "  Key  =  Value  "
                ) } -ModuleName INI

            $result = INI_ReadSection -Filename "fake.ini" -Section "TargetSection"
            $result.Count | Should Be 1
            $result[0].Name | Should Be "Key"
            $result[0].Value | Should Be "Value"
        }

        It "handles duplicate keys (returns all)" {
            Mock Test-Path { return $true } -ModuleName INI
            Mock Get-Content { return @(
                    "[TargetSection]",
                    "Key=Value1",
                    "Key=Value2"
                ) } -ModuleName INI

            $result = INI_ReadSection -Filename "fake.ini" -Section "TargetSection"
            $result.Count | Should Be 2
            $result[0].Value | Should Be "Value1"
            $result[1].Value | Should Be "Value2"
        }

        # Quote Handling Tests
        It "reads unquoted values correctly" {
            Mock Test-Path { return $true } -ModuleName INI
            Mock Get-Content { return @(
                    "[TargetSection]",
                    "Key=UnquotedValue"
                ) } -ModuleName INI
            $result = INI_ReadSection -Filename "fake.ini" -Section "TargetSection"
            $result[0].Value | Should Be "UnquotedValue"
        }

        It "reads quoted values as-is (preserves quotes)" {
            Mock Test-Path { return $true } -ModuleName INI
            Mock Get-Content { return @(
                    "[TargetSection]",
                    'Key="QuotedValue"'
                ) } -ModuleName INI
            $result = INI_ReadSection -Filename "fake.ini" -Section "TargetSection"
            # Based on typical INI parsing in this module (simple string split), 
            # we expect the quotes to be preserved if they are part of the value string.
            # The current implementation does: $matches[2].Trim()
            $result[0].Value | Should Be '"QuotedValue"'
        }

        It "reads mixed quotes correctly" {
            Mock Test-Path { return $true } -ModuleName INI
            Mock Get-Content { return @(
                    "[TargetSection]",
                    'Key=Value"With"Quotes'
                ) } -ModuleName INI
            $result = INI_ReadSection -Filename "fake.ini" -Section "TargetSection"
            $result[0].Value | Should Be 'Value"With"Quotes'
        }
    }

    Context "INI_WriteSection" {
        It "creates a new file if it does not exist" {
            Mock Test-Path { return $false } -ModuleName INI
            Mock Set-Content {} -Verifiable -ModuleName INI

            $data = @([PSCustomObject]@{ Name = "Key"; Value = "Value" })
            $result = INI_WriteSection -Filename "new.ini" -Section "NewSection" -Pairs $data

            $result | Should Be $true
            Assert-MockCalled Set-Content -ModuleName INI -ParameterFilter { 
                $Value -contains "[NewSection]" -and $Value -contains "Key=Value" 
            }
        }

        It "appends to an existing file if section does not exist" {
            Mock Test-Path { return $true } -ModuleName INI
            Mock Get-Content { return @("[ExistingSection]", "Old=Val") } -ModuleName INI
            Mock Set-Content {} -Verifiable -ModuleName INI

            $data = @([PSCustomObject]@{ Name = "NewKey"; Value = "NewVal" })
            $result = INI_WriteSection -Filename "exist.ini" -Section "NewSection" -Pairs $data

            Assert-MockCalled Set-Content -ModuleName INI -ParameterFilter {
                $Value -contains "[ExistingSection]" -and 
                $Value -contains "Old=Val" -and 
                $Value -contains "[NewSection]" -and 
                $Value -contains "NewKey=NewVal"
            }
        }

        It "replaces an existing section" {
            Mock Test-Path { return $true } -ModuleName INI
            Mock Get-Content { return @(
                    "[PriorSection]", "P=1", 
                    "[TargetSection]", "OldKey=OldVal", 
                    "[PostSection]", "P=2"
                ) } -ModuleName INI
            Mock Set-Content {} -Verifiable -ModuleName INI

            $data = @([PSCustomObject]@{ Name = "NewKey"; Value = "NewVal" })
            $result = INI_WriteSection -Filename "exist.ini" -Section "TargetSection" -Pairs $data

            Assert-MockCalled Set-Content -ModuleName INI -ParameterFilter {
                $Value -contains "[PriorSection]" -and
                $Value -contains "[PostSection]" -and
                $Value -contains "[TargetSection]" -and
                $Value -contains "NewKey=NewVal" -and
                -not ($Value -contains "OldKey=OldVal")
            }
        }

        It "warns if Pairs is null" {
            Mock Write-Warning {} -ModuleName INI
            $result = INI_WriteSection -Filename "f.ini" -Section "S" -Pairs $null
            Assert-MockCalled Write-Warning -ModuleName INI
        }
        
        # Quote Handling in Write
        It "writes simple values without adding quotes" {
            Mock Test-Path { return $false } -ModuleName INI
            Mock Set-Content {} -Verifiable -ModuleName INI
             
            $data = @([PSCustomObject]@{ Name = "Key"; Value = "SimpleValue" })
            $result = INI_WriteSection -Filename "test.ini" -Section "Test" -Pairs $data
             
            Assert-MockCalled Set-Content -ModuleName INI -ParameterFilter { $Value -contains "Key=SimpleValue" }
        }

        It "writes values with spaces without adding quotes (implementation dependent)" {
            Mock Test-Path { return $false } -ModuleName INI
            Mock Set-Content {} -Verifiable -ModuleName INI
             
            $data = @([PSCustomObject]@{ Name = "Key"; Value = "Value With Spaces" })
            $result = INI_WriteSection -Filename "test.ini" -Section "Test" -Pairs $data
             
            # Current implementation just does "$($Pair.Name)=$($Pair.Value)"
            # So it should NOT add quotes automatically. 
            Assert-MockCalled Set-Content -ModuleName INI -ParameterFilter { $Value -contains "Key=Value With Spaces" }
        }
        
        It "writes manually quoted values correctly" {
            Mock Test-Path { return $false } -ModuleName INI
            Mock Set-Content {} -Verifiable -ModuleName INI
             
            $data = @([PSCustomObject]@{ Name = "Key"; Value = '"QuotedValue"' })
            $result = INI_WriteSection -Filename "test.ini" -Section "Test" -Pairs $data
             
            Assert-MockCalled Set-Content -ModuleName INI -ParameterFilter { $Value -contains 'Key="QuotedValue"' }
        }
    }
}
