BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../Modules/INI.psm1') -Force -ErrorAction Stop
    Import-Module (Join-Path $PSScriptRoot '../Modules/UE.psm1') -Force -ErrorAction Stop

    if ($IsWindows) {
        $platform = 'Win64'
        $exeExtension = '.exe'
        $scriptExtension = '.bat'
    }
    elseif ($IsMacOS) {
        $platform = 'Mac'
        $exeExtension = ''
        $scriptExtension = '.sh'
    }
    else {
        $platform = 'Linux'
        $exeExtension = ''
        $scriptExtension = '.sh'
    }
}

Describe 'UE.psm1' {
    Context 'UE_GetEngineConfig' {
        BeforeAll {
            $engineRoot = Join-Path $TestDrive 'Custom Engine'
            $engineDir = Join-Path $engineRoot 'Engine'
            $binariesDir = Join-Path $engineDir 'Binaries' $platform
            $batchFilesDir = Join-Path $engineDir 'Build' 'BatchFiles'
        }

        It 'returns native paths and extensions for the current platform' {
            $config = UE_GetEngineConfig -EngineDir $engineDir
            $config.Dirs.Engine | Should -Be $engineDir
            $config.Dirs.Binaries | Should -Be $binariesDir
            $config.Dirs.BatchFiles | Should -Be $batchFilesDir
            $config.Platform | Should -Be $platform
            $config.Extensions.Exe | Should -Be $exeExtension
            $config.Extensions.Script | Should -Be $scriptExtension
            $config.Binaries.Editor | Should -Be (Join-Path $binariesDir "UnrealEditor$exeExtension")
            $config.Binaries.EditorCmd | Should -Be (Join-Path $binariesDir "UnrealEditor-Cmd$exeExtension")
            $config.Binaries.EditorName | Should -Be "UnrealEditor$exeExtension"
            $config.Binaries.EditorCmdName | Should -Be "UnrealEditor-Cmd$exeExtension"
            $config.UAT | Should -Be (Join-Path $batchFilesDir "RunUAT$scriptExtension")
            $config.UBT | Should -Be (Join-Path $batchFilesDir "RunUBT$scriptExtension")
        }

        It 'calculates EngineDir and project generation script from EngineRoot' {
            $config = UE_GetEngineConfig -EngineRoot $engineRoot
            $config.Dirs.Engine | Should -Be $engineDir
            $config.GenerateProjectFiles | Should -Be (Join-Path $engineRoot "GenerateProjectFiles$scriptExtension")
        }

        It 'handles non-default build configurations' {
            $config = UE_GetEngineConfig -EngineDir $engineDir -BuildConfig 'DebugGame'
            $config.Binaries.Editor | Should -Be (Join-Path $binariesDir "UnrealEditor-$platform-DebugGame$exeExtension")
            $config.Binaries.EditorCmd | Should -Be (Join-Path $binariesDir "UnrealEditor-$platform-DebugGame-Cmd$exeExtension")
        }

        It 'requires exactly one engine location' {
            { UE_GetEngineConfig } | Should -Throw '*either pass -EngineDir or -EngineRoot*'
            { UE_GetEngineConfig -EngineDir $engineDir -EngineRoot $engineRoot } | Should -Throw '*either pass -EngineDir or -EngineRoot*'
        }
    }

    Context 'UE_SelectCustomEngine' {
        BeforeEach {
            $engineRoot = (New-Item -ItemType Directory -Path (Join-Path $TestDrive 'My Engine [Dev]') -Force).FullName
            Mock UE_ListCustomEngines {
                [PSCustomObject]@{ Name = 'MyEngine'; Root = $engineRoot }
            } -ModuleName UE
        }

        It 'finds an engine by name' {
            (UE_SelectCustomEngine -Name 'MyEngine').Root | Should -Be $engineRoot
        }

        It 'returns null if the engine is not registered' {
            UE_SelectCustomEngine -Name 'NonExistent' | Should -BeNullOrEmpty
        }

        It 'finds an engine by its normalized root directory' {
            $result = UE_SelectCustomEngine -Root (Join-Path $engineRoot '.')
            $result.Name | Should -Be 'MyEngine'
            $result.Root | Should -Be $engineRoot
        }
    }

    Context 'UE_GetEngineByAssociation' {
        BeforeEach {
            # Registration lookups must never use the host user's real engines.
            Mock UE_SelectCustomEngine { $null } -ModuleName UE
        }

        It 'resolves an explicit association' {
            $engineRoot = Join-Path $TestDrive 'Registered Engine'
            Mock UE_SelectCustomEngine {
                [PSCustomObject]@{ Name = '{GUID}'; Root = $engineRoot }
            } -ModuleName UE -ParameterFilter { $Name -eq '{GUID}' }

            $result = UE_GetEngineByAssociation -EngineAssociation '{GUID}'
            $result.Name | Should -Be '{GUID}'
            $result.Root | Should -Be $engineRoot
            Should -Invoke UE_SelectCustomEngine -ModuleName UE -Times 1 -Exactly -Scope It -ParameterFilter { $Name -eq '{GUID}' }
        }

        It 'finds a registered engine above a nested project directory' {
            $sourceRoot = (New-Item -ItemType Directory -Path (Join-Path $TestDrive 'Source') -Force).FullName
            $null = New-Item -ItemType Directory -Path (Join-Path $sourceRoot 'Engine')
            $projectDir = New-Item -ItemType Directory -Path (Join-Path $sourceRoot 'Games' 'Project') -Force
            $projectFile = (New-Item -ItemType File -Path (Join-Path $projectDir.FullName 'Project.uproject')).FullName
            Mock UE_SelectCustomEngine {
                [PSCustomObject]@{ Name = 'Source'; Root = $sourceRoot }
            } -ModuleName UE -ParameterFilter { $Root -eq $sourceRoot }

            $result = UE_GetEngineByAssociation -UProjectFile $projectFile
            $result.Name | Should -Be 'Source'
            $result.Root | Should -Be $sourceRoot
            Should -Invoke UE_SelectCustomEngine -ModuleName UE -Times 1 -Exactly -Scope It -ParameterFilter { $Root -eq $sourceRoot }
        }

        It 'resolves relative project paths and returns an unregistered engine root' {
            $sourceRoot = (New-Item -ItemType Directory -Path (Join-Path $TestDrive 'Unregistered [Dev]') -Force).FullName
            $null = New-Item -ItemType Directory -Path (Join-Path $sourceRoot 'Engine')
            $projectDir = New-Item -ItemType Directory -Path (Join-Path $sourceRoot 'Project')
            $null = New-Item -ItemType File -Path (Join-Path $projectDir.FullName 'Project.uproject')

            Push-Location -LiteralPath $sourceRoot
            try {
                $result = UE_GetEngineByAssociation -UProjectFile (Join-Path 'Project' 'Project.uproject')
            }
            finally {
                Pop-Location
            }
            $result.Name | Should -BeNullOrEmpty
            $result.Root | Should -Be $sourceRoot
        }

        It 'returns no engine when traversal reaches the filesystem root' {
            $projectDir = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'NoEngine')
            $projectFile = (New-Item -ItemType File -Path (Join-Path $projectDir.FullName 'Project.uproject')).FullName
            # Do not depend on whether an ancestor of TestDrive actually has an Engine directory.
            Mock Test-Path { $false } -ModuleName UE -ParameterFilter { $PathType -eq 'Container' }

            $result = UE_GetEngineByAssociation -UProjectFile $projectFile
            $result.Root | Should -BeNullOrEmpty
            $result.Name | Should -BeNullOrEmpty
            Should -Invoke UE_SelectCustomEngine -ModuleName UE -Times 0 -Exactly -Scope It
        }

        It 'rejects a missing project when the association is empty' {
            { UE_GetEngineByAssociation -UProjectFile (Join-Path $TestDrive 'missing.uproject') } | Should -Throw '*Invalid UProjectFile*'
        }
    }

    Context 'UE_ListCustomEngines platform dispatch' {
        It 'selects the registration backend for the current host' {
            Mock UE_ListCustomEngines_LinuxMac { [PSCustomObject]@{ Name = 'INI'; Root = 'unused' } } -ModuleName UE
            Mock UE_ListCustomEngines_Windows { [PSCustomObject]@{ Name = 'Registry'; Root = 'unused' } } -ModuleName UE

            $result = UE_ListCustomEngines
            if ($IsWindows) {
                $result.Name | Should -Be 'Registry'
                Should -Invoke UE_ListCustomEngines_Windows -ModuleName UE -Times 1 -Exactly -Scope It
                Should -Invoke UE_ListCustomEngines_LinuxMac -ModuleName UE -Times 0 -Exactly -Scope It
            }
            else {
                $result.Name | Should -Be 'INI'
                Should -Invoke UE_ListCustomEngines_LinuxMac -ModuleName UE -Times 1 -Exactly -Scope It
                Should -Invoke UE_ListCustomEngines_Windows -ModuleName UE -Times 0 -Exactly -Scope It
            }
        }
    }

    # These backend unit tests mock I/O and can run on all three platforms.
    Context 'Windows registry backend (mocked)' {
        It 'reads all engine values from a registry key' {
            InModuleScope UE {
                Mock Get-Item {
                    [PSCustomObject]@{ Property = @('Engine1', 'Engine2') }
                } -ParameterFilter { $Path -eq "Registry::$WindowsBuildsRegistryKey" }
                Mock Get-ItemPropertyValue {
                    "C:\$Name"
                } -ParameterFilter { $Path -eq "Registry::$WindowsBuildsRegistryKey" }

                $result = @(UE_ListCustomEngines_Windows)
                $result.Count | Should -Be 2
                $result[0].Name | Should -Be 'Engine1'
                $result[0].Root | Should -Be 'C:\Engine1'
                $result[1].Name | Should -Be 'Engine2'
                $result[1].Root | Should -Be 'C:\Engine2'
                Should -Invoke Get-ItemPropertyValue -Times 1 -Exactly -Scope It -ParameterFilter { $Name -eq 'Engine1' }
                Should -Invoke Get-ItemPropertyValue -Times 1 -Exactly -Scope It -ParameterFilter { $Name -eq 'Engine2' }
            }
        }

        It 'returns no engines for an empty registry key' {
            InModuleScope UE {
                Mock Get-Item { [PSCustomObject]@{ Property = @() } }
                Mock Get-ItemPropertyValue { throw 'An empty key has no values to read' }
                UE_ListCustomEngines_Windows | Should -BeNullOrEmpty
                Should -Invoke Get-ItemPropertyValue -Times 0 -Exactly -Scope It
            }
        }
    }

    Context 'Linux/macOS INI backend (mocked)' {
        It 'reads installations from the platform-specific INI file' {
            InModuleScope UE {
                Mock INI_ReadSection {
                    @(
                        [PSCustomObject]@{ Name = 'Engine1'; Value = '/engines/Engine 1' }
                        [PSCustomObject]@{ Name = 'Engine2'; Value = '/engines/Engine 2' }
                    )
                }

                $result = @(UE_ListCustomEngines_LinuxMac)
                $result.Count | Should -Be 2
                $result[0].Name | Should -Be 'Engine1'
                $result[0].Root | Should -Be '/engines/Engine 1'
                $result[1].Name | Should -Be 'Engine2'
                $result[1].Root | Should -Be '/engines/Engine 2'
                Should -Invoke INI_ReadSection -Times 1 -Exactly -Scope It -ParameterFilter {
                    $Filename -eq ($IsLinux ? '~/.config/Epic/UnrealEngine/Install.ini' : '~/Library/Application Support/Epic/UnrealEngine/Install.ini') -and
                    $Section -eq 'Installations' -and $MayNotExist
                }
            }
        }

        It 'returns no engines when there are no installations' {
            InModuleScope UE {
                Mock INI_ReadSection { $null }
                UE_ListCustomEngines_LinuxMac | Should -BeNullOrEmpty
            }
        }
    }
}
