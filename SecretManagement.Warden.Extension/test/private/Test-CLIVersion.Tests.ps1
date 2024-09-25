BeforeAll {
    . (Join-Path $PSScriptRoot ".." ".." "private" "Test-CLIVersion.ps1")
}

Describe "Test-CLIVersion" {
    BeforeAll {
        [Version]$CurrentVersion = '2024.9.0'
        [Version]$NewerVersion   = '2024.10.0'
        [Version]$OlderVersion   = '2024.8.0'

        # Placing the conversion to string here is neccessary for some reason.
        $bw_version = $CurrentVersion.ToString()
        # Create template bw function for mocking
        function bw {[Alias("bw.exe")][Alias("bw.ps1")]Param() throw "This should always be mocked!" }
    }
    Context "General" {
        BeforeAll {
            $direct = Import-CliXml (Join-Path $PSScriptRoot "mock-cli" "bw-info" "direct.xml")
            Mock $direct -ParameterFilter {$args[0] -eq '--version'} -MockWith { return $bw_version }
        }
        It "Does nothing for valid version" {
            Test-CLIVersion -BitwardenCLI $direct -MinSupportedVersion $OlderVersion -WarningVariable warn -WarningAction Ignore
            $warn | Should -BeNullOrEmpty
        }
        It "Warn when CurrentVersion < MinSupportedVersion" {
            Test-CliVersion -BitwardenCLI $direct -MinSupportedVersion $NewerVersion -WarningVariable warn -WarningAction Ignore
            $warn | Should -Be "Your bitwarden-cli is version $CurrentVersion and is out of date. Please upgrade to at least version $NewerVersion."
        }
    }

    Context "<Source>" -ForEach @(
        @{Source='direct';From='cli';Mocked=(Import-Clixml (Join-Path $PSScriptRoot "mock-cli" "bw-info" "direct.xml"))},
        @{Source='brew';From='pkg-mgr';Mocked=(Import-Clixml (Join-Path $PSScriptRoot "mock-cli" "bw-info" "brew.xml"))},
        @{Source='choco';From='cli';Mocked=(Import-Clixml (Join-Path $PSScriptRoot "mock-cli" "bw-info" "choco.xml"))},
        @{Source='npm';From='pkg-mgr';Mocked=(Import-Clixml (Join-Path $PSScriptRoot "mock-cli" "bw-info" "npm.xml"))},
        @{Source='scoop';From='pkg-mgr';Mocked=(Import-Clixml (Join-Path $PSScriptRoot "mock-cli" "bw-info" "scoop.xml"))},
        @{Source='snap';From='pkg-mgr';Mocked=(Import-Clixml (Join-Path $PSScriptRoot "mock-cli" "bw-info" "snap.xml"))},
        @{Source='winget-machine';From='cli';Mocked=(Import-Clixml (Join-Path $PSScriptRoot "mock-cli" "bw-info" "winget-machine.xml"))},
        @{Source='winget-user';From='cli';Mocked=(Import-Clixml (Join-Path $PSScriptRoot "mock-cli" "bw-info" "winget-user.xml"))}
    ) {
        BeforeEach {
            if($From -eq "cli") {
                Mock -CommandName $Mocked -ParameterFilter {$args[0] -eq "--version"} -MockWith { return $bw_version } -Verifiable
            }
            elseif ($From -eq "pkg-mgr") {
                Mock -CommandName "Get-Command" -ParameterFilter {$Name -eq $Source} -MockWith { return $true }
                Mock -CommandName $Mocked -ParameterFilter {$args[0] -eq "--version"} -MockWith { return $bw_version }

                switch($Source) {
                    "brew"  {
                        function brew { return $null }
                        Mock -CommandName "brew" -ParameterFilter {$args[0] -eq "list" -and $args[1] -eq "bitwarden-cli" -and $args[2] -eq "--versions"} `
                            -MockWith { return Import-Clixml -Path (Join-Path $PSScriptRoot "mock-cli" "response" "brew-list.xml")} -Verifiable
                     }
                    "npm"   {
                        function npm { return $null }
                        Mock -CommandName "npm" -ParameterFilter {$args[0] -eq "view" -and $args[1] -eq "-g" -and $args[2] -eq "@bitwarden/cli" -and $args[3] -eq "version"} `
                            -MockWith { return Import-Clixml -Path (Join-Path $PSScriptRoot "mock-cli" "response" "npm-view.xml") } -Verifiable
                    }
                    "scoop" {
                        function scoop { return $null }
                        Mock -CommandName "scoop" -ParameterFilter {$args[0] -eq "list" -and $args[1] -eq "bitwarden-cli"} `
                            -MockWith { return Import-CliXml -Path (Join-Path $PSScriptRoot "mock-cli" "response" "scoop-list.xml") } -Verifiable
                    }
                    "snap"  {
                        function snap { return $null }
                        Mock -CommandName "snap" -ParameterFilter {$args[0] -eq "list" -and $args[1] -eq "bw"} `
                            -MockWith { return Import-CliXml -Path (Join-Path $PSScriptRoot "mock-cli" "response" "snap-list.xml") } -Verifiable
                    }
                }
            }
        }
        It "Queries the <From> for its version when CurrentVersion < MinSupportedVersion" {
            # Change the Mocked version to an outdated one.  Only works because all mocks are deserialized objects.
            Test-CLIVersion -BitwardenCLI $Mocked -MinSupportedVersion $NewerVersion -WarningAction Ignore | Should -InvokeVerifiable
        }
        It "Does not run <From> query if file version is acceptable" {
            # Change the Mocked version to be an acceptable one.  Only works because all mocks are deserialized objects.
            $Mocked.Version = $CurrentVersion
            Test-CLIVersion -BitwardenCLI $Mocked -MinSupportedVersion $OlderVersion -WarningAction Ignore | Should -Not -InvokeVerifiable
        }
    }
}
