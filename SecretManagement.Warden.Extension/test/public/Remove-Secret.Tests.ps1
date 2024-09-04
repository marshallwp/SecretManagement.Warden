BeforeAll {
    $BasePath = Join-Path $PSScriptRoot ".." ".."
    . (Join-Path $BasePath "public" "Remove-Secret.ps1")
    . (Join-Path $BasePath "private" "Sync-BitwardenVault.ps1")
    . (Join-Path $BasePath "private" "Merge-Defaults.ps1")
    . (Join-Path $BasePath "private" "Invoke-BitwardenCLI")

    Mock Sync-BitwardenVault { }
    Mock Invoke-BitwardenCLI { }
}

Describe "Remove-Secret" {
    It "Invokes Remove Secret" {
        Remove-Secret -AdditionalParameters @{} | Should -Invoke -CommandName Invoke-BitwardenCLI -ParameterFilter {$args[0] -eq "delete" -and $args[1] -eq "item"} -Times 1
    }
}
