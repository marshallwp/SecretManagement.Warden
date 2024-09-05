BeforeAll {
    . (Join-Path $PSScriptRoot ".." ".." "private" "Get-CacheLocation.ps1")
}

Describe "Get-CacheLocation" {
    It "Returns Valid File Path" {
        Get-CacheLocation | Test-Path -PathType Leaf -IsValid | Should -BeTrue
    }
    It "Path is Correct for $($PSVersionTable.OS)" {
        $expected = ($IsWindows) ?
            "$env:LocalAppData\Microsoft\PowerShell\secretmanagement\warden-ext\LastSyncedTime.txt" :
            "$HOME/.secretmanagement/warden-ext/LastSyncedTime.txt"
        Get-CacheLocation | Should -Be $expected
    }
}
