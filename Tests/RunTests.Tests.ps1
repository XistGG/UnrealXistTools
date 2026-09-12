BeforeAll {
    $runner = (Resolve-Path (Join-Path $PSScriptRoot '../RunTests.ps1')).Path
    $pwsh = Join-Path $PSHOME ($IsWindows ? 'pwsh.exe' : 'pwsh')

    function Invoke-RunnerProcess {
        param([string]$ScriptPath, [string[]]$TestPath)

        # Expected failures write stderr. PowerShell 7.0/7.1 applies the error
        # preference to redirected stderr; newer versions can also promote
        # native nonzero exit codes. Limit these preferences to this helper.
        $ErrorActionPreference = 'Continue'
        $PSNativeCommandUseErrorActionPreference = $false
        $arguments = @('-NoLogo', '-NoProfile', '-NonInteractive', '-File', $ScriptPath)
        if ($TestPath) {
            $arguments += @('-Path') + $TestPath
        }
        $output = & $pwsh @arguments 2>&1 | Out-String
        [PSCustomObject]@{ ExitCode = $LASTEXITCODE; Output = $output }
    }
}

Describe 'RunTests.ps1 process contract' {
    It 'runs an explicit test path from another working directory with spaces in the path' {
        $testFile = Join-Path $TestDrive 'passing fixture.Tests.ps1'
        Set-Content -LiteralPath $testFile -Value "Describe 'Fixture' { It 'passes' { 1 | Should -Be 1 } }"

        Push-Location $TestDrive
        try {
            $result = Invoke-RunnerProcess -ScriptPath $runner -TestPath $testFile
        }
        finally {
            Pop-Location
        }
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $result.Output | Should -Match 'Tests Passed: 1'
    }

    It 'finds its default Tests directory independently of the working directory' {
        # Copy only the runner beside a small suite, avoiding recursive execution
        # of the real runner contract tests.
        $fixtureRoot = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'fixture repo')
        $testDir = New-Item -ItemType Directory -Path (Join-Path $fixtureRoot.FullName 'Tests')
        $fixtureRunner = Join-Path $fixtureRoot.FullName 'RunTests.ps1'
        Copy-Item -LiteralPath $runner -Destination $fixtureRunner
        Set-Content -LiteralPath (Join-Path $testDir.FullName 'Fixture.Tests.ps1') -Value "Describe 'Fixture' { It 'passes' { 1 | Should -Be 1 } }"

        Push-Location $TestDrive
        try {
            $result = Invoke-RunnerProcess -ScriptPath $fixtureRunner
        }
        finally {
            Pop-Location
        }
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $result.Output | Should -Match 'Tests Passed: 1'
    }

    It 'returns a nonzero exit code for <Label>' -ForEach @(
        @{
            Label = 'assertion failures'
            Source = "Describe 'Fixture' { It 'fails' { 1 | Should -Be 2 } }"
        }
        @{
            Label = 'BeforeAll failures'
            Source = "Describe 'Fixture' { BeforeAll { throw 'Setup failed' }; It 'never runs' { 1 | Should -Be 1 } }"
        }
        @{
            Label = 'discovery failures'
            Source = "throw 'Discovery failed'"
        }
        @{
            Label = 'syntax errors'
            Source = "Describe 'Unclosed block' {"
        }
    ) {
        $testFile = Join-Path $TestDrive 'failing fixture.Tests.ps1'
        Set-Content -LiteralPath $testFile -Value $Source
        $result = Invoke-RunnerProcess -ScriptPath $runner -TestPath $testFile
        $result.ExitCode | Should -Not -Be 0 -Because $result.Output
    }

    It 'rejects an empty suite rather than reporting success' {
        $testFile = Join-Path $TestDrive 'empty fixture.Tests.ps1'
        Set-Content -LiteralPath $testFile -Value '# No tests'
        $result = Invoke-RunnerProcess -ScriptPath $runner -TestPath $testFile
        $result.ExitCode | Should -Not -Be 0 -Because $result.Output
        $result.Output | Should -Match 'No tests were discovered'
    }
}
