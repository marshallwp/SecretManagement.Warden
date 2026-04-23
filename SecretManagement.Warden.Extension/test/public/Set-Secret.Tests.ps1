BeforeAll {
    $BasePath = Join-Path $PSScriptRoot ".." ".."
    . (Join-Path $BasePath "public" "Set-Secret.ps1")
    . (Join-Path $BasePath "private" "ConvertTo-BWEncoding.ps1")
    . (Join-Path $BasePath "private" "ConvertTo-Hashtable.ps1")
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
                It "Saves the Expected URI string to Login" {
                    $uri = "https://www.example.com"
                    $Secret = @{uris = @($uri)}
                    Set-Secret -Secret $Secret -Name $Name -AdditionalParameters @{} |
                        Should -Invoke -CommandName Invoke-BitwardenCLI -ParameterFilter {
                            ([System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($args[3])) |
                                ConvertFrom-Json).login.uris[0].uri -eq $uri
                        } -Times 1
                }
                It "Saves the Expected URI HashTable to Login" {
                    $Secret = @{uris=@(,@{uri="https://www.example.com"; match="host"})}
                    Set-Secret -Secret $Secret -Name $Name -AdditionalParameters @{} |
                        Should -Invoke -CommandName Invoke-BitwardenCLI -ParameterFilter {
                           $Sample = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($args[3])) | ConvertFrom-Json | ConvertTo-Hashtable

                           $Secret.uris[0].uri -eq $Sample.login.uris[0].uri -and
                           $Secret.uris[0].match -eq $Sample.login.uris[0].match
                        } -Times 1
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

# SIG # Begin signature block
# MIIsBgYJKoZIhvcNAQcCoIIr9zCCK/MCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAyQXQLLQDc92VT
# XzXAGaJjCgBTmaQ77nN/KEN8ZMBkt6CCJRowggVvMIIEV6ADAgECAhBI/JO0YFWU
# jTanyYqJ1pQWMA0GCSqGSIb3DQEBDAUAMHsxCzAJBgNVBAYTAkdCMRswGQYDVQQI
# DBJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcMB1NhbGZvcmQxGjAYBgNVBAoM
# EUNvbW9kbyBDQSBMaW1pdGVkMSEwHwYDVQQDDBhBQUEgQ2VydGlmaWNhdGUgU2Vy
# dmljZXMwHhcNMjEwNTI1MDAwMDAwWhcNMjgxMjMxMjM1OTU5WjBWMQswCQYDVQQG
# EwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMS0wKwYDVQQDEyRTZWN0aWdv
# IFB1YmxpYyBDb2RlIFNpZ25pbmcgUm9vdCBSNDYwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQCN55QSIgQkdC7/FiMCkoq2rjaFrEfUI5ErPtx94jGgUW+s
# hJHjUoq14pbe0IdjJImK/+8Skzt9u7aKvb0Ffyeba2XTpQxpsbxJOZrxbW6q5KCD
# J9qaDStQ6Utbs7hkNqR+Sj2pcaths3OzPAsM79szV+W+NDfjlxtd/R8SPYIDdub7
# P2bSlDFp+m2zNKzBenjcklDyZMeqLQSrw2rq4C+np9xu1+j/2iGrQL+57g2extme
# me/G3h+pDHazJyCh1rr9gOcB0u/rgimVcI3/uxXP/tEPNqIuTzKQdEZrRzUTdwUz
# T2MuuC3hv2WnBGsY2HH6zAjybYmZELGt2z4s5KoYsMYHAXVn3m3pY2MeNn9pib6q
# RT5uWl+PoVvLnTCGMOgDs0DGDQ84zWeoU4j6uDBl+m/H5x2xg3RpPqzEaDux5mcz
# mrYI4IAFSEDu9oJkRqj1c7AGlfJsZZ+/VVscnFcax3hGfHCqlBuCF6yH6bbJDoEc
# QNYWFyn8XJwYK+pF9e+91WdPKF4F7pBMeufG9ND8+s0+MkYTIDaKBOq3qgdGnA2T
# OglmmVhcKaO5DKYwODzQRjY1fJy67sPV+Qp2+n4FG0DKkjXp1XrRtX8ArqmQqsV/
# AZwQsRb8zG4Y3G9i/qZQp7h7uJ0VP/4gDHXIIloTlRmQAOka1cKG8eOO7F/05QID
# AQABo4IBEjCCAQ4wHwYDVR0jBBgwFoAUoBEKIz6W8Qfs4q8p74Klf9AwpLQwHQYD
# VR0OBBYEFDLrkpr/NZZILyhAQnAgNpFcF4XmMA4GA1UdDwEB/wQEAwIBhjAPBgNV
# HRMBAf8EBTADAQH/MBMGA1UdJQQMMAoGCCsGAQUFBwMDMBsGA1UdIAQUMBIwBgYE
# VR0gADAIBgZngQwBBAEwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2NybC5jb21v
# ZG9jYS5jb20vQUFBQ2VydGlmaWNhdGVTZXJ2aWNlcy5jcmwwNAYIKwYBBQUHAQEE
# KDAmMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5jb21vZG9jYS5jb20wDQYJKoZI
# hvcNAQEMBQADggEBABK/oe+LdJqYRLhpRrWrJAoMpIpnuDqBv0WKfVIHqI0fTiGF
# OaNrXi0ghr8QuK55O1PNtPvYRL4G2VxjZ9RAFodEhnIq1jIV9RKDwvnhXRFAZ/ZC
# J3LFI+ICOBpMIOLbAffNRk8monxmwFE2tokCVMf8WPtsAO7+mKYulaEMUykfb9gZ
# pk+e96wJ6l2CxouvgKe9gUhShDHaMuwV5KZMPWw5c9QLhTkg4IUaaOGnSDip0TYl
# d8GNGRbFiExmfS9jzpjoad+sPKhdnckcW67Y8y90z7h+9teDnRGWYpquRRPaf9xH
# +9/DUp/mBlXpnYzyOmJRvOwkDynUWICE5EV7WtgwggYUMIID/KADAgECAhB6I67a
# U2mWD5HIPlz0x+M/MA0GCSqGSIb3DQEBDAUAMFcxCzAJBgNVBAYTAkdCMRgwFgYD
# VQQKEw9TZWN0aWdvIExpbWl0ZWQxLjAsBgNVBAMTJVNlY3RpZ28gUHVibGljIFRp
# bWUgU3RhbXBpbmcgUm9vdCBSNDYwHhcNMjEwMzIyMDAwMDAwWhcNMzYwMzIxMjM1
# OTU5WjBVMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSww
# KgYDVQQDEyNTZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIENBIFIzNjCCAaIw
# DQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAM2Y2ENBq26CK+z2M34mNOSJjNPv
# IhKAVD7vJq+MDoGD46IiM+b83+3ecLvBhStSVjeYXIjfa3ajoW3cS3ElcJzkyZlB
# nwDEJuHlzpbN4kMH2qRBVrjrGJgSlzzUqcGQBaCxpectRGhhnOSwcjPMI3G0hedv
# 2eNmGiUbD12OeORN0ADzdpsQ4dDi6M4YhoGE9cbY11XxM2AVZn0GiOUC9+XE0wI7
# CQKfOUfigLDn7i/WeyxZ43XLj5GVo7LDBExSLnh+va8WxTlA+uBvq1KO8RSHUQLg
# zb1gbL9Ihgzxmkdp2ZWNuLc+XyEmJNbD2OIIq/fWlwBp6KNL19zpHsODLIsgZ+WZ
# 1AzCs1HEK6VWrxmnKyJJg2Lv23DlEdZlQSGdF+z+Gyn9/CRezKe7WNyxRf4e4bwU
# trYE2F5Q+05yDD68clwnweckKtxRaF0VzN/w76kOLIaFVhf5sMM/caEZLtOYqYad
# tn034ykSFaZuIBU9uCSrKRKTPJhWvXk4CllgrwIDAQABo4IBXDCCAVgwHwYDVR0j
# BBgwFoAU9ndq3T/9ARP/FqFsggIv0Ao9FCUwHQYDVR0OBBYEFF9Y7UwxeqJhQo1S
# gLqzYZcZojKbMA4GA1UdDwEB/wQEAwIBhjASBgNVHRMBAf8ECDAGAQH/AgEAMBMG
# A1UdJQQMMAoGCCsGAQUFBwMIMBEGA1UdIAQKMAgwBgYEVR0gADBMBgNVHR8ERTBD
# MEGgP6A9hjtodHRwOi8vY3JsLnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNUaW1l
# U3RhbXBpbmdSb290UjQ2LmNybDB8BggrBgEFBQcBAQRwMG4wRwYIKwYBBQUHMAKG
# O2h0dHA6Ly9jcnQuc2VjdGlnby5jb20vU2VjdGlnb1B1YmxpY1RpbWVTdGFtcGlu
# Z1Jvb3RSNDYucDdjMCMGCCsGAQUFBzABhhdodHRwOi8vb2NzcC5zZWN0aWdvLmNv
# bTANBgkqhkiG9w0BAQwFAAOCAgEAEtd7IK0ONVgMnoEdJVj9TC1ndK/HYiYh9lVU
# acahRoZ2W2hfiEOyQExnHk1jkvpIJzAMxmEc6ZvIyHI5UkPCbXKspioYMdbOnBWQ
# Un733qMooBfIghpR/klUqNxx6/fDXqY0hSU1OSkkSivt51UlmJElUICZYBodzD3M
# /SFjeCP59anwxs6hwj1mfvzG+b1coYGnqsSz2wSKr+nDO+Db8qNcTbJZRAiSazr7
# KyUJGo1c+MScGfG5QHV+bps8BX5Oyv9Ct36Y4Il6ajTqV2ifikkVtB3RNBUgwu/m
# SiSUice/Jp/q8BMk/gN8+0rNIE+QqU63JoVMCMPY2752LmESsRVVoypJVt8/N3qQ
# 1c6FibbcRabo3azZkcIdWGVSAdoLgAIxEKBeNh9AQO1gQrnh1TA8ldXuJzPSuALO
# z1Ujb0PCyNVkWk7hkhVHfcvBfI8NtgWQupiaAeNHe0pWSGH2opXZYKYG4Lbukg7H
# pNi/KqJhue2Keak6qH9A8CeEOB7Eob0Zf+fU+CCQaL0cJqlmnx9HCDxF+3BLbUuf
# rV64EbTI40zqegPZdA+sXCmbcZy6okx/SjwsusWRItFA3DE8MORZeFb6BmzBtqKJ
# 7l939bbKBy2jvxcJI98Va95Q5JnlKor3m0E7xpMeYRriWklUPsetMSf2NvUQa/E5
# vVyefQIwggYaMIIEAqADAgECAhBiHW0MUgGeO5B5FSCJIRwKMA0GCSqGSIb3DQEB
# DAUAMFYxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLTAr
# BgNVBAMTJFNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBSb290IFI0NjAeFw0y
# MTAzMjIwMDAwMDBaFw0zNjAzMjEyMzU5NTlaMFQxCzAJBgNVBAYTAkdCMRgwFgYD
# VQQKEw9TZWN0aWdvIExpbWl0ZWQxKzApBgNVBAMTIlNlY3RpZ28gUHVibGljIENv
# ZGUgU2lnbmluZyBDQSBSMzYwggGiMA0GCSqGSIb3DQEBAQUAA4IBjwAwggGKAoIB
# gQCbK51T+jU/jmAGQ2rAz/V/9shTUxjIztNsfvxYB5UXeWUzCxEeAEZGbEN4QMgC
# sJLZUKhWThj/yPqy0iSZhXkZ6Pg2A2NVDgFigOMYzB2OKhdqfWGVoYW3haT29PST
# ahYkwmMv0b/83nbeECbiMXhSOtbam+/36F09fy1tsB8je/RV0mIk8XL/tfCK6cPu
# YHE215wzrK0h1SWHTxPbPuYkRdkP05ZwmRmTnAO5/arnY83jeNzhP06ShdnRqtZl
# V59+8yv+KIhE5ILMqgOZYAENHNX9SJDm+qxp4VqpB3MV/h53yl41aHU5pledi9lC
# BbH9JeIkNFICiVHNkRmq4TpxtwfvjsUedyz8rNyfQJy/aOs5b4s+ac7IH60B+Ja7
# TVM+EKv1WuTGwcLmoU3FpOFMbmPj8pz44MPZ1f9+YEQIQty/NQd/2yGgW+ufflcZ
# /ZE9o1M7a5Jnqf2i2/uMSWymR8r2oQBMdlyh2n5HirY4jKnFH/9gRvd+QOfdRrJZ
# b1sCAwEAAaOCAWQwggFgMB8GA1UdIwQYMBaAFDLrkpr/NZZILyhAQnAgNpFcF4Xm
# MB0GA1UdDgQWBBQPKssghyi47G9IritUpimqF6TNDDAOBgNVHQ8BAf8EBAMCAYYw
# EgYDVR0TAQH/BAgwBgEB/wIBADATBgNVHSUEDDAKBggrBgEFBQcDAzAbBgNVHSAE
# FDASMAYGBFUdIAAwCAYGZ4EMAQQBMEsGA1UdHwREMEIwQKA+oDyGOmh0dHA6Ly9j
# cmwuc2VjdGlnby5jb20vU2VjdGlnb1B1YmxpY0NvZGVTaWduaW5nUm9vdFI0Ni5j
# cmwwewYIKwYBBQUHAQEEbzBtMEYGCCsGAQUFBzAChjpodHRwOi8vY3J0LnNlY3Rp
# Z28uY29tL1NlY3RpZ29QdWJsaWNDb2RlU2lnbmluZ1Jvb3RSNDYucDdjMCMGCCsG
# AQUFBzABhhdodHRwOi8vb2NzcC5zZWN0aWdvLmNvbTANBgkqhkiG9w0BAQwFAAOC
# AgEABv+C4XdjNm57oRUgmxP/BP6YdURhw1aVcdGRP4Wh60BAscjW4HL9hcpkOTz5
# jUug2oeunbYAowbFC2AKK+cMcXIBD0ZdOaWTsyNyBBsMLHqafvIhrCymlaS98+Qp
# oBCyKppP0OcxYEdU0hpsaqBBIZOtBajjcw5+w/KeFvPYfLF/ldYpmlG+vd0xqlqd
# 099iChnyIMvY5HexjO2AmtsbpVn0OhNcWbWDRF/3sBp6fWXhz7DcML4iTAWS+MVX
# eNLj1lJziVKEoroGs9Mlizg0bUMbOalOhOfCipnx8CaLZeVme5yELg09Jlo8BMe8
# 0jO37PU8ejfkP9/uPak7VLwELKxAMcJszkyeiaerlphwoKx1uHRzNyE6bxuSKcut
# isqmKL5OTunAvtONEoteSiabkPVSZ2z76mKnzAfZxCl/3dq3dUNw4rg3sTCggkHS
# RqTqlLMS7gjrhTqBmzu1L90Y1KWN/Y5JKdGvspbOrTfOXyXvmPL6E52z1NZJ6ctu
# MFBQZH3pwWvqURR8AgQdULUvrxjUYbHHj95Ejza63zdrEcxWLDX6xWls/GDnVNue
# KjWUH3fTv1Y8Wdho698YADR7TNx8X8z2Bev6SivBBOHY+uqiirZtg0y9ShQoPzmC
# cn63Syatatvx157YK9hlcPmVoa1oDE5/L9Uo2bC5a4CH2RwwggZiMIIEyqADAgEC
# AhEApCk7bh7d16c0CIetek63JDANBgkqhkiG9w0BAQwFADBVMQswCQYDVQQGEwJH
# QjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSwwKgYDVQQDEyNTZWN0aWdvIFB1
# YmxpYyBUaW1lIFN0YW1waW5nIENBIFIzNjAeFw0yNTAzMjcwMDAwMDBaFw0zNjAz
# MjEyMzU5NTlaMHIxCzAJBgNVBAYTAkdCMRcwFQYDVQQIEw5XZXN0IFlvcmtzaGly
# ZTEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMTAwLgYDVQQDEydTZWN0aWdvIFB1
# YmxpYyBUaW1lIFN0YW1waW5nIFNpZ25lciBSMzYwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQDThJX0bqRTePI9EEt4Egc83JSBU2dhrJ+wY7JgReuff5KQ
# NhMuzVytzD+iXazATVPMHZpH/kkiMo1/vlAGFrYN2P7g0Q8oPEcR3h0SftFNYxxM
# h+bj3ZNbbYjwt8f4DsSHPT+xp9zoFuw0HOMdO3sWeA1+F8mhg6uS6BJpPwXQjNSH
# pVTCgd1gOmKWf12HSfSbnjl3kDm0kP3aIUAhsodBYZsJA1imWqkAVqwcGfvs6pbf
# s/0GE4BJ2aOnciKNiIV1wDRZAh7rS/O+uTQcb6JVzBVmPP63k5xcZNzGo4DOTV+s
# M1nVrDycWEYS8bSS0lCSeclkTcPjQah9Xs7xbOBoCdmahSfg8Km8ffq8PhdoAXYK
# OI+wlaJj+PbEuwm6rHcm24jhqQfQyYbOUFTKWFe901VdyMC4gRwRAq04FH2VTjBd
# CkhKts5Py7H73obMGrxN1uGgVyZho4FkqXA8/uk6nkzPH9QyHIED3c9CGIJ098hU
# 4Ig2xRjhTbengoncXUeo/cfpKXDeUcAKcuKUYRNdGDlf8WnwbyqUblj4zj1kQZSn
# Zud5EtmjIdPLKce8UhKl5+EEJXQp1Fkc9y5Ivk4AZacGMCVG0e+wwGsjcAADRO7W
# ga89r/jJ56IDK773LdIsL3yANVvJKdeeS6OOEiH6hpq2yT+jJ/lHa9zEdqFqMwID
# AQABo4IBjjCCAYowHwYDVR0jBBgwFoAUX1jtTDF6omFCjVKAurNhlxmiMpswHQYD
# VR0OBBYEFIhhjKEqN2SBKGChmzHQjP0sAs5PMA4GA1UdDwEB/wQEAwIGwDAMBgNV
# HRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMEoGA1UdIARDMEEwNQYM
# KwYBBAGyMQECAQMIMCUwIwYIKwYBBQUHAgEWF2h0dHBzOi8vc2VjdGlnby5jb20v
# Q1BTMAgGBmeBDAEEAjBKBgNVHR8EQzBBMD+gPaA7hjlodHRwOi8vY3JsLnNlY3Rp
# Z28uY29tL1NlY3RpZ29QdWJsaWNUaW1lU3RhbXBpbmdDQVIzNi5jcmwwegYIKwYB
# BQUHAQEEbjBsMEUGCCsGAQUFBzAChjlodHRwOi8vY3J0LnNlY3RpZ28uY29tL1Nl
# Y3RpZ29QdWJsaWNUaW1lU3RhbXBpbmdDQVIzNi5jcnQwIwYIKwYBBQUHMAGGF2h0
# dHA6Ly9vY3NwLnNlY3RpZ28uY29tMA0GCSqGSIb3DQEBDAUAA4IBgQACgT6khnJR
# IfllqS49Uorh5ZvMSxNEk4SNsi7qvu+bNdcuknHgXIaZyqcVmhrV3PHcmtQKt0bl
# v/8t8DE4bL0+H0m2tgKElpUeu6wOH02BjCIYM6HLInbNHLf6R2qHC1SUsJ02MWNq
# RNIT6GQL0Xm3LW7E6hDZmR8jlYzhZcDdkdw0cHhXjbOLsmTeS0SeRJ1WJXEzqt25
# dbSOaaK7vVmkEVkOHsp16ez49Bc+Ayq/Oh2BAkSTFog43ldEKgHEDBbCIyba2E8O
# 5lPNan+BQXOLuLMKYS3ikTcp/Qw63dxyDCfgqXYUhxBpXnmeSO/WA4NwdwP35lWN
# hmjIpNVZvhWoxDL+PxDdpph3+M5DroWGTc1ZuDa1iXmOFAK4iwTnlWDg3QNRsRa9
# cnG3FBBpVHnHOEQj4GMkrOHdNDTbonEeGvZ+4nSZXrwCW4Wv2qyGDBLlKk3kUW1p
# IScDCpm/chL6aUbnSsrtbepdtbCLiGanKVR/KC1gsR0tC6Q0RfWOI4owggaBMIIE
# 6aADAgECAhEA8Eug4XGyod3nbxg/FHoRnTANBgkqhkiG9w0BAQwFADBUMQswCQYD
# VQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSswKQYDVQQDEyJTZWN0
# aWdvIFB1YmxpYyBDb2RlIFNpZ25pbmcgQ0EgUjM2MB4XDTI1MDMyNzAwMDAwMFoX
# DTI4MDMyNjIzNTk1OVowcTELMAkGA1UEBhMCVVMxDjAMBgNVBAgMBVRleGFzMSgw
# JgYDVQQKDB9JbmR1c3RyaWFsIEluZm8gUmVzb3VyY2VzLCBJbmMuMSgwJgYDVQQD
# DB9JbmR1c3RyaWFsIEluZm8gUmVzb3VyY2VzLCBJbmMuMIICIjANBgkqhkiG9w0B
# AQEFAAOCAg8AMIICCgKCAgEAlOjxUyaLg8Q05nT+7PKJmKlNfbP6EO3pGcgMqSm/
# +xp+T4zqlOwZ5XN5eGJAL8NC8TXFM9+DPi/RkMFCGQOPwR2Av6nQCPLwHSMfo+VO
# Vx6dT8BW3yssRnkOeggOYxgUhmgBanaTiXBxlcs/3finlBCiKAhppkvi7feHYokc
# tgeLoMiOl2cOym1qfuReR5gPmLOOem/gtF+5VmzGs7lXI7WwCycfAC+YQgSnF3Qw
# PQRFNSSEJjL/QtvkIBLG/AznzKwQvZpS36gaJUPCEqfZJfSCjJqJkTi0QYkhrQuD
# pXgygRLHnvau8uuyZAhIuhGizlHD+ilyneBytnYNFS4ZPlDwzQSfB6ahwUFd9Jjp
# 177+J9GxTuyljxkgOU0hf4t3DwpEZmT9pXQGR/SJMXx+cbl+mPGAVssaduca57HI
# tfksoEbSQNrypb0C3lWid7/E9diDpRgiTQUzT4XyauOuMoiFBhddD/+XwC6Qi1Cr
# WhexuExo5EiXYaR4qNdkmmHipbpmcnPVAUxMF6cBpPvrP0uD4mBnIxGUfIGh69fi
# ytY1mU1nJgDwOmxAUM5PlR5TuxIcqoVGroPPlYdqKV/itzEdfh506gZZ3w2uUcnn
# 0+tpWmJk/8zIkMJBx+NrQ8rCv4A5Yj9Nxxujq2Wo72XXzcMvf4fqQDbj4JyX/mBz
# NY8CAwEAAaOCAa8wggGrMB8GA1UdIwQYMBaAFA8qyyCHKLjsb0iuK1SmKaoXpM0M
# MB0GA1UdDgQWBBRBGxN507ATdqsNrapJB1QpJdFJ6DAOBgNVHQ8BAf8EBAMCB4Aw
# DAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcDAzBKBgNVHSAEQzBBMDUG
# DCsGAQQBsjEBAgEDAjAlMCMGCCsGAQUFBwIBFhdodHRwczovL3NlY3RpZ28uY29t
# L0NQUzAIBgZngQwBBAEwSQYDVR0fBEIwQDA+oDygOoY4aHR0cDovL2NybC5zZWN0
# aWdvLmNvbS9TZWN0aWdvUHVibGljQ29kZVNpZ25pbmdDQVIzNi5jcmwweQYIKwYB
# BQUHAQEEbTBrMEQGCCsGAQUFBzAChjhodHRwOi8vY3J0LnNlY3RpZ28uY29tL1Nl
# Y3RpZ29QdWJsaWNDb2RlU2lnbmluZ0NBUjM2LmNydDAjBggrBgEFBQcwAYYXaHR0
# cDovL29jc3Auc2VjdGlnby5jb20wJAYDVR0RBB0wG4EZZGpvaGxlQGluZHVzdHJp
# YWxpbmZvLmNvbTANBgkqhkiG9w0BAQwFAAOCAYEAkaWdhLXZ+sS9USbug8Hgdk4S
# yWZbxRAVom3z3zlVuuzWV/ust2FUnwwwOqwdj3S+U7TMpHChHOAloDVMvUNoCXiB
# s1c8UxFNckG5e3nXOga8vZZuonzv1E0PqqF64vFkasVoWoPfcl8q5aYmY1/eYWzk
# hnkJkYG2iUKUgFn8QpuRmCnkjAuKEs1iVrB6d2NNkcZGy7u/tIj5YTNmDmYN4dyT
# coWoIyqInD3u4n5icgWS1gPlQ0A59PRGSRn+p0QYqSEHUwN8x6TP4q5HKTIkYCrx
# gKnrCp9iMY8HRVbOABUlak4Ui9f0q1mdz/zS8bSdmNmDWxfpL1a5OFebkYyIuPMs
# tsoHidh6LC44SSThhtfO9ZnNgL6NWTQgTFFVlX6t+lL3BbdHeoagqhqH04nyT0jJ
# bhrrpXfUaAOY5UIoSfI/QJ27FuobB7hOajAk17DPYTucMUxX5dlQVyrvtsiXQ3rr
# bgMK9YQLWJA16eRDTPU+NFd5n+UR+PE2YlhWLKZ2MIIGgjCCBGqgAwIBAgIQNsKw
# vXwbOuejs902y8l1aDANBgkqhkiG9w0BAQwFADCBiDELMAkGA1UEBhMCVVMxEzAR
# BgNVBAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4wHAYDVQQK
# ExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBSU0Eg
# Q2VydGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMjEwMzIyMDAwMDAwWhcNMzgwMTE4
# MjM1OTU5WjBXMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVk
# MS4wLAYDVQQDEyVTZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIFJvb3QgUjQ2
# MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAiJ3YuUVnnR3d6LkmgZpU
# VMB8SQWbzFoVD9mUEES0QUCBdxSZqdTkdizICFNeINCSJS+lV1ipnW5ihkQyC0cR
# LWXUJzodqpnMRs46npiJPHrfLBOifjfhpdXJ2aHHsPHggGsCi7uE0awqKggE/LkY
# w3sqaBia67h/3awoqNvGqiFRJ+OTWYmUCO2GAXsePHi+/JUNAax3kpqstbl3vcTd
# OGhtKShvZIvjwulRH87rbukNyHGWX5tNK/WABKf+Gnoi4cmisS7oSimgHUI0Wn/4
# elNd40BFdSZ1EwpuddZ+Wr7+Dfo0lcHflm/FDDrOJ3rWqauUP8hsokDoI7D/yUVI
# 9DAE/WK3Jl3C4LKwIpn1mNzMyptRwsXKrop06m7NUNHdlTDEMovXAIDGAvYynPt5
# lutv8lZeI5w3MOlCybAZDpK3Dy1MKo+6aEtE9vtiTMzz/o2dYfdP0KWZwZIXbYsT
# Ilg1YIetCpi5s14qiXOpRsKqFKqav9R1R5vj3NgevsAsvxsAnI8Oa5s2oy25qhso
# BIGo/zi6GpxFj+mOdh35Xn91y72J4RGOJEoqzEIbW3q0b2iPuWLA911cRxgY5SJY
# ubvjay3nSMbBPPFsyl6mY4/WYucmyS9lo3l7jk27MAe145GWxK4O3m3gEFEIkv7k
# RmefDR7Oe2T1HxAnICQvr9sCAwEAAaOCARYwggESMB8GA1UdIwQYMBaAFFN5v1qq
# K0rPVIDh2JvAnfKyA2bLMB0GA1UdDgQWBBT2d2rdP/0BE/8WoWyCAi/QCj0UJTAO
# BgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zATBgNVHSUEDDAKBggrBgEF
# BQcDCDARBgNVHSAECjAIMAYGBFUdIAAwUAYDVR0fBEkwRzBFoEOgQYY/aHR0cDov
# L2NybC51c2VydHJ1c3QuY29tL1VTRVJUcnVzdFJTQUNlcnRpZmljYXRpb25BdXRo
# b3JpdHkuY3JsMDUGCCsGAQUFBwEBBCkwJzAlBggrBgEFBQcwAYYZaHR0cDovL29j
# c3AudXNlcnRydXN0LmNvbTANBgkqhkiG9w0BAQwFAAOCAgEADr5lQe1oRLjlocXU
# EYfktzsljOt+2sgXke3Y8UPEooU5y39rAARaAdAxUeiX1ktLJ3+lgxtoLQhn5cFb
# 3GF2SSZRX8ptQ6IvuD3wz/LNHKpQ5nX8hjsDLRhsyeIiJsms9yAWnvdYOdEMq1W6
# 1KE9JlBkB20XBee6JaXx4UBErc+YuoSb1SxVf7nkNtUjPfcxuFtrQdRMRi/fInV/
# AobE8Gw/8yBMQKKaHt5eia8ybT8Y/Ffa6HAJyz9gvEOcF1VWXG8OMeM7Vy7Bs6mS
# IkYeYtddU1ux1dQLbEGur18ut97wgGwDiGinCwKPyFO7ApcmVJOtlw9FVJxw/mL1
# TbyBns4zOgkaXFnnfzg4qbSvnrwyj1NiurMp4pmAWjR+Pb/SIduPnmFzbSN/G8re
# ZCL4fvGlvPFk4Uab/JVCSmj59+/mB2Gn6G/UYOy8k60mKcmaAZsEVkhOFuoj4we8
# CYyaR9vd9PGZKSinaZIkvVjbH/3nlLb0a7SBIkiRzfPfS9T+JesylbHa1LtRV9U/
# 7m0q7Ma2CQ/t392ioOssXW7oKLdOmMBl14suVFBmbzrt5V5cQPnwtd3UOTpS9oCG
# +ZZheiIvPgkDmA8FzPsnfXW5qHELB43ET7HHFHeRPRYrMBKjkb8/IN7Po0d0hQoF
# 4TeMM+zYAJzoKQnVKOLg8pZVPT8xggZCMIIGPgIBATBpMFQxCzAJBgNVBAYTAkdC
# MRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxKzApBgNVBAMTIlNlY3RpZ28gUHVi
# bGljIENvZGUgU2lnbmluZyBDQSBSMzYCEQDwS6DhcbKh3edvGD8UehGdMA0GCWCG
# SAFlAwQCAQUAoIGEMBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcN
# AQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUw
# LwYJKoZIhvcNAQkEMSIEIFRnZW2RNUqNDzvQwOI5+1TvxPxoMC5LW7k7S6d348hY
# MA0GCSqGSIb3DQEBAQUABIICACzHtCsjnKdbTBsEoFzYizQP/al4VwxWvh5Eevx4
# FZWUghdDWSyYwMsH27uP8k5x6A3qL/VlrDnjYL9M/AmaW6XlgVRfV1+e+LuakMSb
# JfzHKNutAYbUKyHhIl9Q3RE3+6PFF6AXAgyEJhmstNKJ0xYxwAgwdLO61tfeoTfe
# Lww8ed2SP0OmM2Mjkp+2f+SpIQBG8ASejNMYoGJH/pXCBZ+5z9PLTtiQi27M1wSb
# RFJSIHdkLOZ+pihkFP9MkhIC/peGGlSMHgocGEzGvNZwgB5b7HA67FPdjV3Onokm
# hS7mbriIi80Lk9NMI2xP33IcXIQkOjrmJ48mVplzH0q5/wHcK3rXH0hJhSmKF6iH
# a7zYEMoOX0aaKBKgh5AujmyyzXiQO6BV8jTowGqVNhV9B0olmFDx9ynx3+xcanlW
# dODlwTov66VsQQIaOQm5qw/XU0162UXDBVGKFOMsnux3vSRvpwOnL/bbTx/yqkJ9
# OpxlCwfLvK/MS8xe8VR0dkNJLb3vDvzLZWTWypSI0LdOSM2wucoEvqyGiPh3CqyR
# l6nvkL5dsO8A6bNfM8uqkLnuu6Rvp3lc8fvNF0axi3+JcTg+RN7BT6/VMp6SEU39
# 9LjhfQVEzTh8Y1rVNUcdr1quaMA8CMHweARK/5K6zS0sE++lf289dJ+KT+rbyrQN
# ljc3oYIDIzCCAx8GCSqGSIb3DQEJBjGCAxAwggMMAgEBMGowVTELMAkGA1UEBhMC
# R0IxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEsMCoGA1UEAxMjU2VjdGlnbyBQ
# dWJsaWMgVGltZSBTdGFtcGluZyBDQSBSMzYCEQCkKTtuHt3XpzQIh616TrckMA0G
# CWCGSAFlAwQCAgUAoHkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG
# 9w0BCQUxDxcNMjYwNDIzMTg0MDA4WjA/BgkqhkiG9w0BCQQxMgQwP53JXx8nVob3
# wG6JOCIgE+vp14h3/7lZDDrI62syVSN1IDhHastLou0qTRQT4sLBMA0GCSqGSIb3
# DQEBAQUABIICAMXgW0Lg/D2cZw2d2/BGyL+CJOwCnyxg9daha9/B9bODr/KCRNNd
# lX9E8Qhpzi5EntMQrD2LduLFbZ90N9Ox8/enZ5fv1iYK2XEdt9SIUEC5IdVBHtJp
# ZQLzEYI2bZKZ71KWFeNZHOUbMlz6OZVApwmmmXVFSxImv2ayjctYT4+FCg1iGARq
# bq+AAD14ltcef7DSwkwWZGfw7mgsEtgZmDsC2EUE+uFLjsKP21x/mdskaKcxveXQ
# vB51IwscZOk5MqqMRZ2kvMlPXsobkqZueh40shIUFBHKJuvYZgLxuqnTF/Yatfez
# 8LSLGBT1DkqGLJssmnP6bYNIxRJeUIgGpiHz5bg3dHuO6mj2cO9spuUMTVxTrK+L
# lNHh4PzGf4BOdG38aQxC0pv+jRa6ZKXAlyka0mA1KVJGes8AJhsawymd6ZDn2sBm
# EMsIrkfxLMG/G9rx48VtZ3j56VKNRlaj0xgzY0ltp0Cc6Pv6N5cU6SIXpCac72qm
# ZeV+P96FdV9fhgkLTUUWNiIbmmcuGcCt5p8NRKIoqFXgyE1szCmYtCVa6r8p3MeN
# OlcQY9vh6N2TF90TJDBboydZQ3uJclWXQMm/z+oxMAEuumRw55Vm/44ALSlkiR4D
# TMeuckLFNqaLUyGg2gR7bo0D2ec3z3H1IozDbid90CpwS8b21n6EUVHJ
# SIG # End signature block
