BeforeAll {
    $BasePath = Join-Path $PSScriptRoot ".." ".."
    . (Join-Path $BasePath "public" "Set-Secret.ps1")
    . (Join-Path $BasePath "private" "ConvertTo-BWEncoding.ps1")
    . (Join-Path $BasePath "private" "Get-FullSecret.ps1")
    . (Join-Path $BasePath "private" "Invoke-BitwardenCLI")
    . (Join-Path $BasePath "private" "Merge-Defaults.ps1")
    . (Join-Path $BasePath "private" "New-Secret.ps1")
    . (Join-Path $BasePath "private" "Sync-BitwardenVault.ps1")
    . (Join-Path $BasePath "private" "Test-KeysInHashtable.ps1")
    . (Join-Path $BasePath "classes" "BitwardenEnum.ps1")

    # Mock the following functions to do nothing.
    Mock Sync-BitwardenVault { }
    Mock Invoke-BitwardenCLI { }

    # Mock New-Secret returns.
    Mock New-Secret -ParameterFilter {$SecretType -eq "Login"} `
        -MockWith { return Import-Clixml (Join-Path $PSScriptRoot "mock" "new-secrets" "login.xml") }
    Mock New-Secret -ParameterFilter {$SecretType -eq "Card"} `
        -MockWith { return Import-Clixml (Join-Path $PSScriptRoot "mock" "new-secrets" "card.xml") }
    Mock New-Secret -ParameterFilter {$SecretType -eq "Identity"} `
        -MockWith { return Import-Clixml (Join-Path $PSScriptRoot "mock" "new-secrets" "identity.xml") }
    Mock New-Secret -ParameterFilter {$SecretType -eq "SecureNote"} `
        -MockWith { return Import-Clixml (Join-Path $PSScriptRoot "mock" "new-secrets" "secure-note.xml") }
}

<# TODO: Add tests that validate edits were made.
Test for:
    - Editing Secrets
    - Creating New Secrets
    - Different Types of Secrets

Process Flow:
- Get Existing/New Secret
- If New, perform different actions based on the input secret data type
- If Existing, perform different actions based on both the existing secret type and the input data type
- Send the secret back to bitwarden using either create or edit commands
#>

Describe "Set-Secret"{
    Context "Create Secret" {
        BeforeAll {
             # Get-FullSecret must always return $null for non-existent secrets
            Mock Get-FullSecret { return $null }
        }
        Context "Input Secret is PSCredential" {
            BeforeAll {
                $password = ConvertTo-SecureString "MyPlainTextPassword" -AsPlainText -Force
                $Secret = New-Object System.Management.Automation.PSCredential ("username", $password)
            }
            It "Creates a Login" {
                Set-Secret -Secret $Secret -Name "TestSecret" -AdditionalParameters @{} |
                    Should -Invoke -CommandName New-Secret -ParameterFilter {$SecretType -eq "Login"} -Times 1
            }
            It "Runs Create Operation Against Vault" {
                Set-Secret -Secret $Secret -Name "TestSecret" -AdditionalParameters @{} |
                    Should -Invoke -CommandName Invoke-BitwardenCLI -ParameterFilter {$args[0] -eq "create"} -Times 1
            }
        }
        Context "Input Secret is <Type>" -ForEach @(
            @{Type="String"; Secret="Test String"},
            @{Type="SecureString"; Secret=ConvertTo-SecureString "Test Secure String" -AsPlainText -Force}
        ) {
            It "Asks what type of secret to create" {
                Mock Read-Host { return "UserName" }
                Set-Secret -Secret $Secret -Name "TestSecret" -AdditionalParameters @{} |
                    Should -Invoke -CommandName Read-Host -Times 1
            }
            It "Throws error on an invalid response" {
                Mock Read-Host { return "InvalidType" }
                { Set-Secret -Secret $Secret -Name "TestSecret" -AdditionalParameters @{} } | Should -Throw
            }
            It "Creates a Login When Answer is <Answer>" -ForEach @(
                @{Answer="UserName"},@{Answer="Password"},@{Answer="TOTP"},@{Answer="URIs"}) {
                Mock Read-Host { return $Answer }
                Set-Secret -Secret $Secret -Name "TestSecret" -AdditionalParameters @{} |
                    Should -Invoke -CommandName New-Secret -ParameterFilter {$SecretType -eq "Login"} -Times 1
            }
            It "Creates a SecureNote When Answer is SecureNote" {
                Mock Read-Host { return "SecureNote" }
                Set-Secret -Secret $Secret -Name "TestSecret" -AdditionalParameters @{} |
                    Should -Invoke -CommandName New-Secret -ParameterFilter {$SecretType -eq "SecureNote"} -Times 1
            }
            It "Runs Create Operation Against Vault" {
                Mock Read-Host { return "SecureNote" }
                Set-Secret -Secret $Secret -Name "TestSecret" -AdditionalParameters @{} |
                    Should -Invoke -CommandName Invoke-BitwardenCLI -ParameterFilter {$args[0] -eq "create"} -Times 1
            }
        }
        Context "Input Secret is HashTable" {
            Context "Single Property HashTables" {
                Context "Creates a <ExpectedType> when Property <Prop> Exists" -ForEach @(
                    @{Prop="UserName"; ExpectedType="Login"},
                    @{Prop="Password"; ExpectedType="Login"},
                    @{Prop="cardholderName";ExpectedType="Card"},
                    @{Prop="brand";ExpectedType="Card"},
                    @{Prop="number";ExpectedType="Card"},
                    @{Prop="expMonth";ExpectedType="Card"},
                    @{Prop="expYear";ExpectedType="Card"},
                    @{Prop="code";ExpectedType="Card"},
                    @{Prop="address1"; ExpectedType="Identity"},
                    @{Prop="address2"; ExpectedType="Identity"},
                    @{Prop="address3"; ExpectedType="Identity"},
                    @{Prop="city"; ExpectedType="Identity"},
                    @{Prop="company"; ExpectedType="Identity"},
                    @{Prop="country"; ExpectedType="Identity"},
                    @{Prop="email"; ExpectedType="Identity"},
                    @{Prop="firstName"; ExpectedType="Identity"},
                    @{Prop="lastName"; ExpectedType="Identity"},
                    @{Prop="licenseNumber"; ExpectedType="Identity"},
                    @{Prop="middleName"; ExpectedType="Identity"},
                    @{Prop="passportNumber"; ExpectedType="Identity"},
                    @{Prop="phone"; ExpectedType="Identity"},
                    @{Prop="postalCode"; ExpectedType="Identity"},
                    @{Prop="ssn"; ExpectedType="Identity"},
                    @{Prop="state"; ExpectedType="Identity"},
                    @{Prop="title"; ExpectedType="Identity"}
                ) {
                    BeforeAll { $Secret = @{"$Prop" = "test"} }
                    It "Generates <ExpectedType> Secret" {
                        Set-Secret -Secret $Secret -Name "TestSecret" -AdditionalParameters @{} |
                            Should -Invoke -CommandName New-Secret -ParameterFilter {$SecretType -eq $ExpectedType} -Times 1
                    }
                    It "Runs Create Operation Against Vault" {
                        Set-Secret -Secret $Secret -Name "TestSecret" -AdditionalParameters @{} |
                            Should -Invoke -CommandName Invoke-BitwardenCLI -ParameterFilter {$args[0] -eq "create"} -Times 1
                    }
                }
            }
            Context "Multi-Property Hashtables" {
                BeforeDiscovery {
                    $LoginHash = @{
                        UserName = Get-Random
                        Password = Get-Random
                    }
                    $CardHash = @{
                        cardholderName = Get-Random
                        brand = Get-Random
                        number = Get-Random
                        expMonth = Get-Random
                        expYear = Get-Random
                        code = Get-Random
                    }
                    $IdentityHash = @{
                        address1 = Get-Random
                        address2 = Get-Random
                        address3 = Get-Random
                        city = Get-Random
                        company = Get-Random
                        country = Get-Random
                        email = Get-Random
                        firstName = Get-Random
                        lastName = Get-Random
                        licenseNumber = Get-Random
                        middleName = Get-Random
                        passportNumber = Get-Random
                        phone = Get-Random
                        postalCode = Get-Random
                        ssn = Get-Random
                        state = Get-Random
                        title = Get-Random
                    }
                }
                Context "<SecType> <Priority>" -ForEach @(
                    @{SecType="Login"; Priority="Has Primacy"; Secret=$LoginHash + $CardHash + $IdentityHash},
                    @{SecType="Card"; Priority="is Secondary"; Secret=$CardHash + $IdentityHash},
                    @{SecType="Identity"; Priority="is Tertiary"; Secret=$IdentityHash},
                    @{SecType="SecureNote"; Priority="is Default"; Secret=@{Text="Pester Testing Test Text."}}
                ) {
                    It "Generates a <SecType> Secret" {
                        Set-Secret -Secret $Secret -Name "TestSecret" -AdditionalParameters @{} |
                            Should -Invoke -CommandName New-Secret -ParameterFilter {$SecretType -eq $SecType} -Times 1
                    }
                    It "Runs Create Operation Against Vault" {
                        Set-Secret -Secret $Secret -Name "TestSecret" -AdditionalParameters @{} |
                            Should -Invoke -CommandName Invoke-BitwardenCLI -ParameterFilter {$args[0] -eq "create"} -Times 1
                    }
                }
            }
        }
    }
    Context "Edit Secret" {
        Context "Existing Login" {
            BeforeAll {
                Mock Get-FullSecret { return Import-Clixml (Join-Path $PSScriptRoot "mock" "full-secrets" "login.xml") }
                $Name = '92662bb0-5339-4de3-a69f-65a536e93173'
            }
            It "Throws an Error on Invalid Secret DataType: Int32" {
                $Secret = [Int32]64
                { Set-Secret -Secret $Secret -Name $Name -AdditionalParameters @{} } | Should -Throw "Casting data of*type*is not supported."
            }
            Context "Input Secret is PSCredential" {
                BeforeAll {
                    $password = ConvertTo-SecureString "MyPlainTextPassword" -AsPlainText -Force
                    $Secret = New-Object System.Management.Automation.PSCredential ("username", $password)
                }
                It "Alters existing login creds" {
                    Mock ConvertFrom-SecureString {return "MyPlainTextPassword"}
                    Set-Secret -Secret $Secret -Name $Name -AdditionalParameters @{} |
                        Should -Invoke -CommandName ConvertFrom-SecureString -Times 1
                }
                It "Runs Edit Operation Against Vault" {
                    Set-Secret -Secret $Secret -Name $Name -AdditionalParameters @{} |
                        Should -Invoke -CommandName Invoke-BitwardenCLI -ParameterFilter {$args[0] -eq "edit"} -Times 1
                }
            }
            Context "Input Secret is <Type>" -ForEach @(
                @{Type="String"; Secret="Test String"},
                @{Type="SecureString"; Secret=ConvertTo-SecureString "Test Secure String" -AsPlainText -Force}
            ) {
                It "Asks which field the secret updates" {
                    Mock Read-Host { return "UserName" }
                    Set-Secret -Secret $Secret -Name $Name -AdditionalParameters @{} |
                        Should -Invoke -CommandName Read-Host -Times 1
                }
                It "Throws an error on an invalid response" {
                    Mock Read-Host { return "InvalidType" }
                    { Set-Secret -Secret $Secret -Name $Name -AdditionalParameters @{} } | Should -Throw
                }
                It "Runs Edit Operation Against Vault" {
                    Mock Read-Host { return "UserName" }
                    Set-Secret -Secret $Secret -Name $Name -AdditionalParameters @{} |
                        Should -Invoke -CommandName Invoke-BitwardenCLI -ParameterFilter {$args[0] -eq "edit"} -Times 1
                }
            }
            Context "Input Secret is HashTable" {
                It "Throws error on incompatible input HashTable" {
                    $Secret = @{Invalid="HashTable"}
                    { Set-Secret -Secret $Secret -Name $Name -AdditionalParameters @{} } | Should -Throw "*Secret could not be cast*"
                }
                It "Runs Edit Operation Against Vault" {
                    $Secret = @{UserName="New User"}
                    Set-Secret -Secret $Secret -Name $Name -AdditionalParameters @{} |
                        Should -Invoke -CommandName Invoke-BitwardenCLI -ParameterFilter {$args[0] -eq "edit"} -Times 1
                }
            }
        }
        Context "Existing Card" {
            BeforeAll {
                Mock Get-FullSecret { return Import-Clixml (Join-Path $PSScriptRoot "mock" "full-secrets" "card.xml") }
                $Name = 'd229e6b7-7aee-43ca-ba4c-ae0503a2b1f5'
            }
            It "Throws an Error on Invalid Secret DataType: <DataType>" -ForEach @(
                @{DataType="Int32"; Sample=[Int32]64},
                @{DataType="String"; Sample="Test String"},
                @{DataType="SecureString"; Sample=ConvertTo-SecureString "Test String" -AsPlainText -Force},
                @{DataType="PSCredential"; Sample=New-Object System.Management.Automation.PSCredential ("username", (ConvertTo-SecureString "Test String" -AsPlainText -Force))}
            ) {
                { Set-Secret -Secret $Sample -Name $Name -AdditionalParameters @{} } | Should -Throw "Casting data of*type*is not supported."
            }
            Context "Input Secret is HashTable" {
                It "Throws error on incompatible input HashTable" {
                    $Secret = @{Invalid="HashTable"}
                    { Set-Secret -Secret $Secret -Name $Name -AdditionalParameters @{} } | Should -Throw "*Secret could not be cast*"
                }
                It "Runs Edit Operation Against Vault" {
                    $Secret = @{cardholderName="New User"}
                    Set-Secret -Secret $Secret -Name $Name -AdditionalParameters @{} |
                        Should -Invoke -CommandName Invoke-BitwardenCLI -ParameterFilter {$args[0] -eq "edit"} -Times 1
                }
            }
        }
        Context "Existing Identity" {
            BeforeAll {
                Mock Get-FullSecret { return Import-Clixml (Join-Path $PSScriptRoot "mock" "full-secrets" "identity.xml") }
                $Name = '7d6ab3c5-f28d-416d-b947-fded30d70ac1'
            }
            It "Throws an Error on Invalid Secret DataType: <DataType>" -ForEach @(
                @{DataType="Int32"; Sample=[Int32]64},
                @{DataType="String"; Sample="Test String"},
                @{DataType="SecureString"; Sample=ConvertTo-SecureString "Test String" -AsPlainText -Force},
                @{DataType="PSCredential"; Sample=New-Object System.Management.Automation.PSCredential ("username", (ConvertTo-SecureString "Test String" -AsPlainText -Force))}
            ) {
                { Set-Secret -Secret $Sample -Name $Name -AdditionalParameters @{} } | Should -Throw "Casting data of*type*is not supported."
            }
            It "Runs Edit Operation Against Vault" {
                $Secret = @{company="Example Company"}
                Set-Secret -Secret $Secret -Name $Name -AdditionalParameters @{} |
                    Should -Invoke -CommandName Invoke-BitwardenCLI -ParameterFilter {$args[0] -eq "edit"} -Times 1
            }
        }
        Context "Existing SecureNote" {
            BeforeAll {
                Mock Get-FullSecret { return Import-Clixml (Join-Path $PSScriptRoot "mock" "full-secrets" "secure-note.xml") }
                $Name = 'f6c97ce7-953e-4c06-a12e-45e1b16be4df'
            }
            It "Throws an Error on Invalid Secret DataType: <DataType>" -ForEach @(
                @{DataType="Int32"; Sample=[Int32]64},
                @{DataType="PSCredential"; Sample=New-Object System.Management.Automation.PSCredential ("username", (ConvertTo-SecureString "Test String" -AsPlainText -Force))}
            ) {
                { Set-Secret -Secret $Sample -Name $Name -AdditionalParameters @{} } | Should -Throw "Casting data of*type*is not supported."
            }
            It "Runs Edit Operation Against Vault" {
                $Secret = @{Text="SampleText"}
                Set-Secret -Secret $Secret -Name $Name -AdditionalParameters @{} |
                    Should -Invoke -CommandName Invoke-BitwardenCLI -ParameterFilter {$args[0] -eq "edit"} -Times 1
            }
        }
    }
}
