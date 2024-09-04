BeforeAll {
    . (Join-Path $PSScriptRoot ".." ".." "classes" "BitwardenPasswordHistory.ps1")
}

Describe "BitwardenPasswordHistory Class" {
    BeforeAll {
        [object]$PasswordHistory = @{LastUsedDate = Get-Date; Password = "SuperSecretPassword"}
    }
    It "Ingests PasswordHistory Object" {
        {[BitwardenPasswordHistory]::new($PasswordHistory)} | Should -Not -Throw
    }

    Context "Validate Properties" {
        BeforeAll {
            $Example = [BitwardenPasswordHistory]::new($PasswordHistory)
        }
        It "LastUsedDate is DateTime" {
            $Example.LastUsedDate | Should -BeOfType DateTime
        }
        It "Password is SecureString" {
            $Example.Password | Should -BeOfType SecureString
        }
    }

    Context "Test Methods" {
        BeforeAll {
            $Example = [BitwardenPasswordHistory]::new($PasswordHistory)
        }
        It "Reveal() Returns String" {
            $Example.Reveal() | Should -BeOfType String
        }
        It "Reveal() Returns Password in PlainText" {
            $Example.Reveal() | Should -BeExactly $PasswordHistory.Password
        }
    }

}
