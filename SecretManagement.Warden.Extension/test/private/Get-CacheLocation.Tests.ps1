BeforeAll {
    . (Join-Path $PSScriptRoot ".." ".." "private" "Get-CacheLocation.ps1")
}

Describe "Get-CacheLocation" {
    It "Returns Valid File Path" {
        Get-CacheLocation | Test-Path -PathType Leaf -IsValid | Should -BeTrue
    }
}
