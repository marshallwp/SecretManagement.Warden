BeforeAll {
    . (Join-Path $PSScriptRoot ".." ".." "public" "Test-SecretVault.ps1")
    . (Join-Path $PSScriptRoot ".." ".." "private" "Sync-BitwardenVault.ps1")
    . (Join-Path $PSScriptRoot ".." ".." "private" "Merge-Defaults.ps1")
    . (Join-Path $PSScriptRoot ".." ".." "private" "Invoke-BitwardenCLI")

    Mock Sync-BitwardenVault { }
}

Mock Invoke-BitwardenCLI -ParameterFilter {$args[0] -eq "login" -and $args[1] -eq "--check" -and $args[2] -eq "--quiet"} -MockWith { return $LoginCheck }

Describe "Test-SecretVault" {
    Context "User is logged out" {
        BeforeAll {
            Mock Invoke-BitwardenCLI -ParameterFilter {$args[0] -eq "login" -and $args[1] -eq "--check" -and $args[2] -eq "--quiet"} -MockWith { return $false }
            Mock Invoke-BitwardenCLI -ParameterFilter {$args[0] -eq "list" -and $args[1] -eq "folders" -and $args[2] -eq "--quiet"} -Verifiable
        }
        It "Returns logged out error" {
            { Test-SecretVault -AdditionalParameters @{} -ErrorAction Stop } | Should -Throw
        }
        It "Does not check if the vault is locked" {
            Test-SecretVault -AdditionalParameters @{} -ErrorAction Ignore | Should -Not -InvokeVerifiable
        }
    }
    Context "User is logged in" {
        BeforeAll {
            Mock Invoke-BitwardenCLI -ParameterFilter {$args[0] -eq "login" -and $args[1] -eq "--check" -and $args[2] -eq "--quiet"} -MockWith { return $true }
        }
        It "Returns <Value> if Vault is <State>" -ForEach @(
            @{State="Locked";Value=$false},
            @{State="Unlocked";Value=$true}
        ) {
            Mock Invoke-BitwardenCLI -ParameterFilter {$args[0] -eq "list" -and $args[1] -eq "folders" -and $args[2] -eq "--quiet"} -MockWith { return $Value }
            Test-SecretVault -AdditionalParameters @{} -ErrorAction Ignore | Should -Be $Value
        }
        It "Forcibly Resyncs the Vault if it is Unlocked" {
            Mock Invoke-BitwardenCLI -ParameterFilter {$args[0] -eq "list" -and $args[1] -eq "folders" -and $args[2] -eq "--quiet"} -MockWith { return $true }
            Test-SecretVault -AdditionalParameters @{}
            Should -Invoke -CommandName Sync-BitwardenVault -ParameterFilter { $Force -eq $true } -Times 1
        }
    }
}
