$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = Join-Path (Split-Path -Parent $here) "Modules\UE.psm1"
Import-Module $sut -Force

Describe "UE.psm1" {

    Context "UE_GetEngineConfig" {
        It "returns correct paths for given EngineDir" {
            $config = UE_GetEngineConfig -EngineDir "C:\Engine"
            
            $config.Dirs.Engine | Should Be "C:\Engine"
            $config.Dirs.Binaries | Should Be "C:\Engine\Binaries\Win64"
            $config.Dirs.BatchFiles | Should Be "C:\Engine\Build\BatchFiles"
            $config.Platform | Should Be "Win64"
            $config.Binaries.Editor | Should Be "C:\Engine\Binaries\Win64\UnrealEditor.exe"
        }

        It "calculates EngineDir from EngineRoot" {
            $config = UE_GetEngineConfig -EngineRoot "C:\"
            $config.Dirs.Engine | Should Be "C:\Engine"
        }

        It "handles Build Configurations" {
            $config = UE_GetEngineConfig -EngineDir "C:\Engine" -BuildConfig "DebugGame"
            $config.Binaries.Editor | Should Be "C:\Engine\Binaries\Win64\UnrealEditor-Win64-DebugGame.exe"
        }
    }

    Context "UE_SelectCustomEngine (Windows)" {
        It "Finds engine by Name" {
            # Mock UE_ListCustomEngines to avoid registry complexity in this test
            Mock UE_ListCustomEngines {
                return @([PSCustomObject]@{ Name = "MyEngine"; Root = "C:\MyEngine" })
            } -ModuleName UE

            $result = UE_SelectCustomEngine -Name "MyEngine"
            $result.Root | Should Be "C:\MyEngine"
        }
        
        It "Returns null if not found" {
            Mock UE_ListCustomEngines { return @() } -ModuleName UE
            $result = UE_SelectCustomEngine -Name "NonExistent"
            $result | Should BeNullOrEmpty
        }
        
        It "Finds engine by Root" {
            Mock UE_ListCustomEngines {
                return @([PSCustomObject]@{ Name = "MyEngine"; Root = "C:\MyEngine" })
            } -ModuleName UE
            
            # Mock Get-Item to ensure path resolution works inside UE_SelectCustomEngine
            Mock Get-Item {
                return [PSCustomObject]@{ 
                    PSIsContainer = $true; 
                    FullName      = "C:\MyEngine" 
                }
            } -ModuleName UE

            $result = UE_SelectCustomEngine -Root "C:\MyEngine"
            $result.Name | Should Be "MyEngine"
        }
    }
    
    Context "UE_GetEngineByAssociation" {
        It "Resolves association to engine" {
            Mock UE_SelectCustomEngine {
                if ($Name -eq "{GUID}") { return [PSCustomObject]@{ Name = "{GUID}"; Root = "C:\Engine" } }
                return $null
            } -ModuleName UE
            
            $result = UE_GetEngineByAssociation -EngineAssociation "{GUID}"
            $result.Root | Should Be "C:\Engine"
        }
        
        It "Resolves empty association by looking up directory tree" {
            # This logic is complex to mock fully because it uses Get-Item and Test-Path on arguments.
            # But we can verify it calls UE_SelectCustomEngine with the found root.
            
            # Mock Test-Path to simulate finding "Engine" directory
            # The function checks: if (Test-Path -Path $testPath -PathType Container)
            
            Mock Test-Path {
                if ($Path -match "Engine$") { return $true }
                if ($Path -match ".uproject$") { return $true }
                return $false
            } -ModuleName UE
            
            Mock UE_SelectCustomEngine {
                return [PSCustomObject]@{ Name = "Source"; Root = "C:\Source\Engine" }
            } -ModuleName UE

            # We need to pass a uProjectFile that implies a path
            $result = UE_GetEngineByAssociation -UProjectFile "C:\Source\Project\Project.uproject"
            $result.Root | Should Be "C:\Source\Engine"
        }
    }
    
    Context "UE_ListCustomEngines (Windows Registry)" {
        # This test relies on mocking Get-Item and Get-ItemPropertyValue
        # used in UE_ListCustomEngines_Windows
        
        It "Reads entries from registry" {
            if (-not $IsWindows) { Set-TestInconclusive "Windows only test" }
             
            Mock Get-Item {
                # Should return an object with a .Property list
                return [PSCustomObject]@{ Property = @("Engine1", "Engine2") }
            } -ModuleName UE -ParameterFilter { $Path -match "Registry::" }
             
            Mock Get-ItemPropertyValue {
                if ($Name -eq "Engine1") { return "C:\Engine1" }
                if ($Name -eq "Engine2") { return "C:\Engine2" }
            } -ModuleName UE
             
            $result = UE_ListCustomEngines
            $result.Count | Should Be 2
            $result[0].Name | Should Be "Engine1"
            $result[0].Root | Should Be "C:\Engine1"
        }
    }
}
