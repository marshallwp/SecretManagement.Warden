BeforeAll {
    $BasePath = Join-Path $PSScriptRoot ".." ".."
    . (Join-Path $BasePath "private" "Get-FullSecret.ps1")
    . (Join-Path $BasePath "private" "Merge-Defaults.ps1")
    . (Join-Path $BasePath "private" "Sync-BitwardenVault.ps1")
    . (Join-Path $BasePath "private" "Invoke-BitwardenCLI.ps1")
}

Describe "Get-FullSecret" {
    BeforeAll {
        Mock Sync-BitwardenVault { }
    }
    It "Returns '`$null' for non-existent secret." {
        Mock Invoke-BitwardenCLI {
            $ex = New-Object System.Management.Automation.ItemNotFoundException "Not found."
            Write-Error $ex -Category ObjectNotFound -ErrorAction Stop
        }
        Get-FullSecret -Name '00000000-0000-0000-0000-000000000000' | Should -BeNullOrEmpty
    }
    It "Returns Expected Secret Object" {
        Mock Invoke-BitwardenCLI { return Get-Content (Join-Path $PSScriptRoot "example-secret" "example-secret.json") }
        $expected = Import-Clixml -Path (Join-Path $PSScriptRoot "example-secret" "example-secret.xml")
        $test = Get-FullSecret -Name '92662bb0-5339-4de3-a69f-65a536e93173'
        Compare-Object -ReferenceObject $expected -DifferenceObject $test | Should -BeNullOrEmpty
    }
}
