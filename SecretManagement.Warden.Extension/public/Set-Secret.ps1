function Set-Secret
{
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "VaultName", Justification = "Function must accept this parameter to be valid.")]
    param (
        [string] $Name,
        # SecretManagement supports secrets of types: byte[], string, SecureString, PSCredential, and HashTable.
        [object] $Secret,
        [string] $VaultName,
        [hashtable] $AdditionalParameters
    )

    # Enable Verbose Mode inside this script if passed from the wrapper.
    if($AdditionalParameters.ContainsKey('Verbose') -and ($AdditionalParameters['Verbose'] -eq $true)) {$script:VerbosePreference = 'Continue'}
    $AdditionalParameters = Merge-Defaults $AdditionalParameters
    Sync-BitwardenVault $AdditionalParameters.ResyncCacheIfOlderThan

    $OldSecret = Get-FullSecret -Name $Name -AdditionalParameters $AdditionalParameters
    $IsNewItem = $false

    # If OldSecret does not exist, assume this is a new secret and retrieve a secret template.
    if( !$OldSecret ) {
        $IsNewItem = $true

        switch( $Secret.GetType().Name ) {
            "PSCredential" {
                $OldSecret = New-Secret -Name $Name -SecretType Login
                break
            }
            { "String","SecureString" -contains $Secret.GetType().Name } {
                $Field = Read-Host -Prompt "Is this $($Secret.GetType().Name) a UserName, Password, TOTP, URIs, or SecureNote?"

                if( $Field -iin "UserName","Password","TOTP","URIs" ) {
                    $OldSecret = New-Secret -Name $Name -SecretType Login
                } elseif( $Field -ieq "SecureNote" ) {
                    $OldSecret = New-Secret -Name $Name -SecretType SecureNote
                } else {
                    $ex = New-Object System.Management.Automation.Host.PromptingException "$Field is not a valid option!"
                    Write-Error -Exception $ex -Category InvalidArgument -ErrorId "InvalidUserInput" -ErrorAction Stop
                }
                break
            }
            "HashTable" {
                if( Test-KeysInHashtable $Secret @("UserName","Password") ) {
                    $OldSecret = New-Secret -Name $Name -SecretType Login
                }
                elseif( Test-KeysInHashtable $Secret @("cardholderName","brand","number","expMonth","expYear","code") ) {
                    $OldSecret = New-Secret -Name $Name -SecretType Card
                }
                # Identity also includes a username field, but as that more strongly implies a login it is not used to detect an identity.
                elseif( Test-KeysInHashtable $Secret @("address1","address2","address3","city","company","country","email","firstName","lastName","licenseNumber","middleName","passportNumber","phone","postalCode","ssn","state","title") ) {
                    $OldSecret = New-Secret -Name $Name -SecretType Identity
                }
                else {
                    $OldSecret = New-Secret -Name $Name -SecretType SecureNote
                }
                break
            }
        }
    }
    else {
        # OldSecret.type is retrieved as a number; map it to our enum so it works in the next step.
        $OldSecret.type = [BitwardenItemType]$OldSecret.type
    }

    # Do things differently based on what type of secret we're editing.
    switch($OldSecret.type) {
        "Login" {
            # Do things differently based on what type of information the new secret is.
            switch($Secret.GetType().Name) {
                "PSCredential" {
                    if($Secret.UserName -or $IsNewItem) { $OldSecret.login.username = $Secret.UserName }
                    if($Secret.Password -or $IsNewItem) { $OldSecret.login.password = ConvertFrom-SecureString $Secret.Password -AsPlainText }
                    break
                }
                "HashTable" {
                    if ( Test-KeysInHashtable $Secret @("userName","password","uris","totp") ) {
                        if($Secret.UserName -or $IsNewItem) {
                            $OldSecret.login.username = if($Secret.UserName -is [SecureString])
                                { ConvertFrom-SecureString $Secret.UserName -AsPlainText } else { [string]$Secret.UserName }
                        }
                        if($Secret.Password -or $IsNewItem) {
                            $OldSecret.login.password = if($Secret.Password -is [SecureString])
                                { ConvertFrom-SecureString $Secret.Password -AsPlainText } else { [string]$Secret.Password }
                        }
                        if($Secret.uris) { $OldSecret.login.uris = @([string]$Secret.uris) } elseif($IsNewItem) { $OldSecret.login.uris = @() }
                        if($Secret.totp -or $IsNewItem) {
                            $OldSecret.login.totp = if($Secret.totp -is [SecureString])
                                { ConvertFrom-SecureString $Secret.totp -AsPlainText } else { [string]$Secret.totp }
                        }
                    }
                    else {
                        $ex = New-Object System.Management.Automation.PSInvalidCastException "Input [HashTable]Secret could not be cast to any part of a Bitwarden Login."
                        Write-Error -Exception $ex -Category InvalidOperation -CategoryReason "Hashtable does not contain UserName, Password, URIs, or TOTP." -ErrorAction Stop
                    }
                    break
                }
                { "String","SecureString" -contains $_ } {
                    # Only prompt if the user hasn't answered this question before.
                    if( !$Field ) {
                        $Field = Read-Host -Prompt "Does this $($Secret.GetType().Name) update the UserName, Password, TOTP, or URIs field?"
                    }

                    if( $Field -iin "UserName","Password","TOTP" ) {
                        $OldSecret.login.$Field = if( $Secret -is [SecureString] )  { ConvertFrom-SecureString $Secret -AsPlainText } else { $Secret }
                    }
                    elseif( $Field -ieq "URIs" ) {
                        $OldSecret.login.uris = @( if( $Secret -is [SecureString] )  { ConvertFrom-SecureString $Secret -AsPlainText } else { $Secret } )
                    }
                    else {
                        $ex = New-Object System.Management.Automation.Host.PromptingException "$Field is not a valid option!"
                        Write-Error -Exception $ex -Category InvalidArgument -ErrorId "InvalidUserInput" -ErrorAction Stop
                    }

                    # If this is a new item, clear out all the default values.
                    if($IsNewItem) {
                        ($OldSecret.login | Get-Member -MemberType NoteProperty).Name | Where-Object { $_ -ine $Field } | ForEach-Object {
                            if($_ -ine "URIs") { $OldSecret.login.$_ = $null } else { $OldSecret.login.$_ = $() }
                        }
                    }
                    break
                }
                default {
                    $ex = New-Object System.Management.Automation.PSInvalidCastException "Casting data of $($Secret.GetType().Name) type to a Bitwarden Login is not supported."
                    Write-Error -Exception $ex -Category InvalidType -ErrorId "InvalidCast" -ErrorAction Stop
                    break
                }
            }
            break
        }
        "SecureNote" {
            # Do things differently based on what type of information the new secret is.
            switch($Secret.GetType().Name) {
                "String" { $OldSecret.notes = $Secret; break }
                "SecureString" { $OldSecret.notes = ConvertFrom-SecureString $Secret -AsPlainText; break }
                "HashTable" {
                    $ObjTemplate = "PowerShellObjectRepresentation: {0}`n{1}"
                    switch($AdditionalParameters.ExportObjectsToSecureNotesAs) {
                        "CliXml" {
                            $tmp = New-TemporaryFile
                            $Secret | Export-Clixml -Depth $AdditionalParameters.MaximumObjectDepth -Path $tmp
                            $OldSecret.notes = $ObjTemplate -f "CliXml", (Get-Content -Path $tmp -Raw)
                            Remove-Item $tmp -Force
                            break
                        }
                        "JSON" {
                            $OldSecret.notes = $ObjTemplate -f "JSON", ($Secret | ConvertTo-Json -Depth $AdditionalParameters.MaximumObjectDepth -Compress)
                            break
                        }
                        default {
                            $ex = New-Object System.NotSupportedException "$($AdditionalParameters.ExportObjectsToSecureNotesAs) is not a supported means of representing a PowerShell Object."
                            Write-Error -Exception $ex -Category NotImplemented -ErrorId "InvalidObjectRepresentation" -RecommendedAction "Change the Vault Parameter: ExportObjectsToSecureNotesAs to a supported value." -ErrorAction Stop
                            break
                        }
                    }
                    break
                }
                default {
                    $ex = New-Object System.Management.Automation.PSInvalidCastException "Casting data of $($Secret.GetType().Name) type to a Bitwarden Secure Note is not supported."
                    Write-Error -Exception $ex -Category InvalidType -ErrorId "InvalidCast" -ErrorAction Stop
                    break
                }
            }
            break
        }
        "Card" {
            switch($Secret.GetType().Name) {
                "HashTable" {
                    $cardFields = "cardholderName","brand","number","expMonth","expYear","code"
                    if ( Test-KeysInHashtable $Secret $cardFields ) {
                        $cardFields | ForEach-Object {
                            if($Secret.$_ -or $IsNewItem) {
                                $OldSecret.card.$_ = if($Secret.$_ -is [SecureString])
                                { ConvertFrom-SecureString $Secret.$_ -AsPlainText } else { [string]$Secret.$_ }
                            }
                        }
                    }
                    else {
                        $ex = New-Object System.Management.Automation.PSInvalidCastException "Input [HashTable]Secret could not be cast to any part of a Bitwarden Card."
                        Write-Error -Exception $ex -Category InvalidOperation -CategoryReason "Hashtable missing any relevant information." -ErrorAction Stop
                    }
                    break
                }
                default {
                    $ex = New-Object System.Management.Automation.PSInvalidCastException "Casting data of $($Secret.GetType().Name) type to a Bitwarden Card is not supported."
                    Write-Error -Exception $ex -Category InvalidType -ErrorId "InvalidCast" -ErrorAction Stop
                    break
                }
            }
            break
        }
        "Identity" {
            switch($Secret.GetType().Name) {
                "HashTable" {
                    $identFields = "address1","address2","address3","city","company","country","email","firstName","lastName","licenseNumber","middleName","passportNumber","phone","postalCode","ssn","state","title","userName"
                    if ( Test-KeysInHashtable $Secret $identFields ) {
                        $identFields | ForEach-Object {
                            if($Secret.$_ -or $IsNewItem) {
                                $OldSecret.identity.$_ = if($Secret.$_ -is [SecureString])
                                { ConvertFrom-SecureString $Secret.$_ -AsPlainText } else { [string]$Secret.$_ }
                            }
                        }
                    }
                    else {
                        $ex = New-Object System.Management.Automation.PSInvalidCastException "Input [HashTable]Secret could not be cast to any part of a Bitwarden Identity."
                        Write-Error -Exception $ex -Category InvalidOperation -CategoryReason "Hashtable missing any relevant information." -ErrorAction Stop
                    }
                    break
                }
                default {
                    $ex = New-Object System.Management.Automation.PSInvalidCastException "Casting data of $($Secret.GetType().Name) type to a Bitwarden Identity is not supported."
                    Write-Error -Exception $ex -Category InvalidType -ErrorId "InvalidCast" -ErrorAction Stop
                    break
                }
            }
            break
        }
    }

    if( $IsNewItem ) { [System.Collections.Generic.List[string]]$CmdParams = @("create","item") }
                else { [System.Collections.Generic.List[string]]$CmdParams = @("edit","item"); $CmdParams.Add($OldSecret.id) }

    $NewSecret = $OldSecret | ConvertTo-Json -Depth 4 -Compress | ConvertTo-BWEncoding
    $CmdParams.Add( $NewSecret )

    if ( $AdditionalParameters.ContainsKey('organizationid')) {
        $CmdParams.Add( '--organizationid' )
        $CmdParams.Add( $AdditionalParameters['organizationid'] )
    }

    Write-Verbose ($CmdParams -join " ")

    Invoke-BitwardenCLI @CmdParams
}

# SIG # Begin signature block
# MIIsEQYJKoZIhvcNAQcCoIIsAjCCK/4CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDWY0YLDCrFcw3/
# 0CglpNwH9m1skW2IGK0s9Zc5P6ZAW6CCJSYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# cn63Syatatvx157YK9hlcPmVoa1oDE5/L9Uo2bC5a4CH2RwwggZdMIIExaADAgEC
# AhA6UmoshM5V5h1l/MwS2OmJMA0GCSqGSIb3DQEBDAUAMFUxCzAJBgNVBAYTAkdC
# MRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLDAqBgNVBAMTI1NlY3RpZ28gUHVi
# bGljIFRpbWUgU3RhbXBpbmcgQ0EgUjM2MB4XDTI0MDExNTAwMDAwMFoXDTM1MDQx
# NDIzNTk1OVowbjELMAkGA1UEBhMCR0IxEzARBgNVBAgTCk1hbmNoZXN0ZXIxGDAW
# BgNVBAoTD1NlY3RpZ28gTGltaXRlZDEwMC4GA1UEAxMnU2VjdGlnbyBQdWJsaWMg
# VGltZSBTdGFtcGluZyBTaWduZXIgUjM1MIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEAjdFn9MFIm739OEk6TWGBm8PY3EWlYQQ2jQae45iWgPXUGVuYoIa1
# xjTGIyuw3suUSBzKiyG0/c/Yn++d5mG6IyayljuGT9DeXQU9k8GWWj2/BPoamg2f
# FctnPsdTYhMGxM06z1+Ft0Bav8ybww21ii/faiy+NhiUM195+cFqOtCpJXxZ/lm9
# tpjmVmEqpAlRpfGmLhNdkqiEuDFTuD1GsV3jvuPuPGKUJTam3P53U4LM0UCxeDI8
# Qz40Qw9TPar6S02XExlc8X1YsiE6ETcTz+g1ImQ1OqFwEaxsMj/WoJT18GG5KiNn
# S7n/X4iMwboAg3IjpcvEzw4AZCZowHyCzYhnFRM4PuNMVHYcTXGgvuq9I7j4ke28
# 1x4e7/90Z5Wbk92RrLcS35hO30TABcGx3Q8+YLRy6o0k1w4jRefCMT7b5mTxtq5X
# PmKvtgfPuaWPkGZ/tbxInyNDA7YgOgccULjp4+D56g2iuzRCsLQ9ac6AN4yRbqCY
# sG2rcIQ5INTyI2JzA2w1vsAHPRbUTeqVLDuNOY2gYIoKBWQsPYVoyzaoBVU6O5TG
# +a1YyfWkgVVS9nXKs8hVti3VpOV3aeuaHnjgC6He2CCDL9aW6gteUe0AmC8XCtWw
# pePx6QW3ROZo8vSUe9AR7mMdu5+FzTmW8K13Bt8GX/YBFJO7LWzwKAUCAwEAAaOC
# AY4wggGKMB8GA1UdIwQYMBaAFF9Y7UwxeqJhQo1SgLqzYZcZojKbMB0GA1UdDgQW
# BBRo76QySWm2Ujgd6kM5LPQUap4MhTAOBgNVHQ8BAf8EBAMCBsAwDAYDVR0TAQH/
# BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDBKBgNVHSAEQzBBMDUGDCsGAQQB
# sjEBAgEDCDAlMCMGCCsGAQUFBwIBFhdodHRwczovL3NlY3RpZ28uY29tL0NQUzAI
# BgZngQwBBAIwSgYDVR0fBEMwQTA/oD2gO4Y5aHR0cDovL2NybC5zZWN0aWdvLmNv
# bS9TZWN0aWdvUHVibGljVGltZVN0YW1waW5nQ0FSMzYuY3JsMHoGCCsGAQUFBwEB
# BG4wbDBFBggrBgEFBQcwAoY5aHR0cDovL2NydC5zZWN0aWdvLmNvbS9TZWN0aWdv
# UHVibGljVGltZVN0YW1waW5nQ0FSMzYuY3J0MCMGCCsGAQUFBzABhhdodHRwOi8v
# b2NzcC5zZWN0aWdvLmNvbTANBgkqhkiG9w0BAQwFAAOCAYEAsNwuyfpPNkyKL/bJ
# T9XvGE8fnw7Gv/4SetmOkjK9hPPa7/Nsv5/MHuVus+aXwRFqM5Vu51qfrHTwnVEx
# cP2EHKr7IR+m/Ub7PamaeWfle5x8D0x/MsysICs00xtSNVxFywCvXx55l6Wg3lXi
# PCui8N4s51mXS0Ht85fkXo3auZdo1O4lHzJLYX4RZovlVWD5EfwV6Ve1G9UMslnm
# 6pI0hyR0Zr95QWG0MpNPP0u05SHjq/YkPlDee3yYOECNMqnZ+j8onoUtZ0oC8Ckb
# OOk/AOoV4kp/6Ql2gEp3bNC7DOTlaCmH24DjpVgryn8FMklqEoK4Z3IoUgV8R9qQ
# Lg1dr6/BjghGnj2XNA8ujta2JyoxpqpvyETZCYIUjIs69YiDjzftt37rQVwIZsfC
# Yv+DU5sh/StFL1x4rgNj2t8GccUfa/V3iFFW9lfIJWWsvtlC5XOOOQswr1UmVdNW
# Qem4LwrlLgcdO/YAnHqY52QwnBLiAuUnuBeshWmfEb5oieIYMIIGgjCCBGqgAwIB
# AgIQNsKwvXwbOuejs902y8l1aDANBgkqhkiG9w0BAQwFADCBiDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4w
# HAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVz
# dCBSU0EgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMjEwMzIyMDAwMDAwWhcN
# MzgwMTE4MjM1OTU5WjBXMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBM
# aW1pdGVkMS4wLAYDVQQDEyVTZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIFJv
# b3QgUjQ2MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAiJ3YuUVnnR3d
# 6LkmgZpUVMB8SQWbzFoVD9mUEES0QUCBdxSZqdTkdizICFNeINCSJS+lV1ipnW5i
# hkQyC0cRLWXUJzodqpnMRs46npiJPHrfLBOifjfhpdXJ2aHHsPHggGsCi7uE0awq
# KggE/LkYw3sqaBia67h/3awoqNvGqiFRJ+OTWYmUCO2GAXsePHi+/JUNAax3kpqs
# tbl3vcTdOGhtKShvZIvjwulRH87rbukNyHGWX5tNK/WABKf+Gnoi4cmisS7oSimg
# HUI0Wn/4elNd40BFdSZ1EwpuddZ+Wr7+Dfo0lcHflm/FDDrOJ3rWqauUP8hsokDo
# I7D/yUVI9DAE/WK3Jl3C4LKwIpn1mNzMyptRwsXKrop06m7NUNHdlTDEMovXAIDG
# AvYynPt5lutv8lZeI5w3MOlCybAZDpK3Dy1MKo+6aEtE9vtiTMzz/o2dYfdP0KWZ
# wZIXbYsTIlg1YIetCpi5s14qiXOpRsKqFKqav9R1R5vj3NgevsAsvxsAnI8Oa5s2
# oy25qhsoBIGo/zi6GpxFj+mOdh35Xn91y72J4RGOJEoqzEIbW3q0b2iPuWLA911c
# RxgY5SJYubvjay3nSMbBPPFsyl6mY4/WYucmyS9lo3l7jk27MAe145GWxK4O3m3g
# EFEIkv7kRmefDR7Oe2T1HxAnICQvr9sCAwEAAaOCARYwggESMB8GA1UdIwQYMBaA
# FFN5v1qqK0rPVIDh2JvAnfKyA2bLMB0GA1UdDgQWBBT2d2rdP/0BE/8WoWyCAi/Q
# Cj0UJTAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zATBgNVHSUEDDAK
# BggrBgEFBQcDCDARBgNVHSAECjAIMAYGBFUdIAAwUAYDVR0fBEkwRzBFoEOgQYY/
# aHR0cDovL2NybC51c2VydHJ1c3QuY29tL1VTRVJUcnVzdFJTQUNlcnRpZmljYXRp
# b25BdXRob3JpdHkuY3JsMDUGCCsGAQUFBwEBBCkwJzAlBggrBgEFBQcwAYYZaHR0
# cDovL29jc3AudXNlcnRydXN0LmNvbTANBgkqhkiG9w0BAQwFAAOCAgEADr5lQe1o
# RLjlocXUEYfktzsljOt+2sgXke3Y8UPEooU5y39rAARaAdAxUeiX1ktLJ3+lgxto
# LQhn5cFb3GF2SSZRX8ptQ6IvuD3wz/LNHKpQ5nX8hjsDLRhsyeIiJsms9yAWnvdY
# OdEMq1W61KE9JlBkB20XBee6JaXx4UBErc+YuoSb1SxVf7nkNtUjPfcxuFtrQdRM
# Ri/fInV/AobE8Gw/8yBMQKKaHt5eia8ybT8Y/Ffa6HAJyz9gvEOcF1VWXG8OMeM7
# Vy7Bs6mSIkYeYtddU1ux1dQLbEGur18ut97wgGwDiGinCwKPyFO7ApcmVJOtlw9F
# VJxw/mL1TbyBns4zOgkaXFnnfzg4qbSvnrwyj1NiurMp4pmAWjR+Pb/SIduPnmFz
# bSN/G8reZCL4fvGlvPFk4Uab/JVCSmj59+/mB2Gn6G/UYOy8k60mKcmaAZsEVkhO
# Fuoj4we8CYyaR9vd9PGZKSinaZIkvVjbH/3nlLb0a7SBIkiRzfPfS9T+JesylbHa
# 1LtRV9U/7m0q7Ma2CQ/t392ioOssXW7oKLdOmMBl14suVFBmbzrt5V5cQPnwtd3U
# OTpS9oCG+ZZheiIvPgkDmA8FzPsnfXW5qHELB43ET7HHFHeRPRYrMBKjkb8/IN7P
# o0d0hQoF4TeMM+zYAJzoKQnVKOLg8pZVPT8wggaSMIIE+qADAgECAhEA9BsIJ9y5
# ugHUWmIFDcoPyDANBgkqhkiG9w0BAQwFADBUMQswCQYDVQQGEwJHQjEYMBYGA1UE
# ChMPU2VjdGlnbyBMaW1pdGVkMSswKQYDVQQDEyJTZWN0aWdvIFB1YmxpYyBDb2Rl
# IFNpZ25pbmcgQ0EgUjM2MB4XDTIyMDMyMzAwMDAwMFoXDTI1MDMyMjIzNTk1OVow
# fjELMAkGA1UEBhMCVVMxDjAMBgNVBAgMBVRleGFzMSgwJgYDVQQKDB9JbmR1c3Ry
# aWFsIEluZm8gUmVzb3VyY2VzLCBJbmMuMQswCQYDVQQLDAJJVDEoMCYGA1UEAwwf
# SW5kdXN0cmlhbCBJbmZvIFJlc291cmNlcywgSW5jLjCCAiIwDQYJKoZIhvcNAQEB
# BQADggIPADCCAgoCggIBAJ7E7i62hCOgQLnF+wZZo8Rfl4dLolApxc+xD6cbXmk7
# 67hIZ/c7P+QCmLsZGqaZBKT+pBz2HKchvi3I1BqANkPa9arn2MYTRQZ1I57IJmZb
# /TwgybUxKtiyZxjYjw74iRmcReCa52Zyv7TethAR/v5ygApM8HzCgWoqa9/IWGcR
# SpHKWHHcINmLO/DO/8BXD93T9fCfRdY4L69H2QbQkNh0lye1QTp/70VDu1o83sdW
# eGrXJhCZvpZlEeEgUUEG2M5zwJr4Ro2ZEVATCAp3BPt/2rjniGh2Zos7yD2+1Wmr
# OgTBYVw/K+Yk265zjhF0asr7Ek4frWaccPjiBYWCxDDvLKn7hMfQP8FTD+qzMAsW
# ls2Zn05R1gHrttlZ8gbYaQXNaOYFhKat6w25emvD9sJPFFJVZCvnp9Pz+fKQhEhq
# ffWeMZBLFdlQoLIvDkhJWs9+jbnowitu0KKlk0dkiQVLYUIQpiPRhPGaJKscyHzA
# Q87DD3Ox/6S/TGhNJFMM3hFuvRnaZ2P12cVvHmD8OqVSwDhQsl01Fg8VioGrd0Bx
# gNP5bWiTz+eMRChf0o3JVpj9Ortz6sdTwAJgE8Dd8Im+5sRRWfBHROS3sCR5pgYE
# JdmNMARcbA7tecdKK20eP+AkyH4t8Hevx3hMKhS4nZArU/kCE4nGhAv0n4/riHWn
# AgMBAAGjggGzMIIBrzAfBgNVHSMEGDAWgBQPKssghyi47G9IritUpimqF6TNDDAd
# BgNVHQ4EFgQUfukDRLukn0rpdU1Lx5oydHrJyCowDgYDVR0PAQH/BAQDAgeAMAwG
# A1UdEwEB/wQCMAAwEwYDVR0lBAwwCgYIKwYBBQUHAwMwSgYDVR0gBEMwQTA1Bgwr
# BgEEAbIxAQIBAwIwJTAjBggrBgEFBQcCARYXaHR0cHM6Ly9zZWN0aWdvLmNvbS9D
# UFMwCAYGZ4EMAQQBMEkGA1UdHwRCMEAwPqA8oDqGOGh0dHA6Ly9jcmwuc2VjdGln
# by5jb20vU2VjdGlnb1B1YmxpY0NvZGVTaWduaW5nQ0FSMzYuY3JsMHkGCCsGAQUF
# BwEBBG0wazBEBggrBgEFBQcwAoY4aHR0cDovL2NydC5zZWN0aWdvLmNvbS9TZWN0
# aWdvUHVibGljQ29kZVNpZ25pbmdDQVIzNi5jcnQwIwYIKwYBBQUHMAGGF2h0dHA6
# Ly9vY3NwLnNlY3RpZ28uY29tMCgGA1UdEQQhMB+BHWhvc3RtYXN0ZXJAaW5kdXN0
# cmlhbGluZm8uY29tMA0GCSqGSIb3DQEBDAUAA4IBgQBXt+ecda0VKyotd+pMQHR1
# r84lxw40P6/NADb14P48p0iQYoFXBNmyq3kGtv4VFYVSDiiu/823nxt7Zm/0JtBN
# 2WcLmt61ZELp23N+MxMAMSvriQ+PGMSXdix8w3aY3AJACUM0+gmynqTVpwhsZBkh
# xMlX0OpeFNv6VfoAvLo5rNZ5wD0KwlFTEid1WiOQImHHOC7kkQIuj6POkrby9ukD
# wbDIwRDgwpZEik2K5JtD/+kKBIK1Zrs6g8nnVPS+vjv494vDZBR6XCrct4HrAJfd
# U+Ch7/cTlo4DG4MePpEwMUml/GIQsU8uOqkf932TW6wm1oF6PGh0mysMVZ9ee+CB
# iL3WwZ6uV2yyZ2+k2+wQr4HaM24OPp6r1ubGrAwclydFLBzI6cbxcRzakcPJ6Elu
# Q3FdZyyB2S/S9yWTi//MIFsFbmywhhr0MrH6bwU4zPzuYOFVTvr6Ek/Cu8ZsEFne
# Z/7T8KEgoDSmL3XESd6KYLWkzMgPWqmGZTHmzZbaXzIxggZBMIIGPQIBATBpMFQx
# CzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxKzApBgNVBAMT
# IlNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBDQSBSMzYCEQD0Gwgn3Lm6AdRa
# YgUNyg/IMA0GCWCGSAFlAwQCAQUAoIGEMBgGCisGAQQBgjcCAQwxCjAIoAKAAKEC
# gAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwG
# CisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIO5llLfwulQaa3iktjzL6L9teQw+
# srRRHA85e7H3UVVdMA0GCSqGSIb3DQEBAQUABIICAJz9qde3BLC1sKSMwF+BnDze
# 3mTxAk4qZz/7Ng27TaSOntduQ9/58BTfZ+lv6t/DCzKqyxqye28TM3iW2lc7pSoy
# xdc4maWNzmJOoasaoOm0fvqQhGWZaLTKeM4nAhnZye8SAK8Gt+9tIuHwR5XSdVI5
# 3jDzabHrwzn2NbSUSHEADzGmh8VZsBuLkthRoak8931nYHy+hC0BfUTneGO9FHTn
# 5IuOKyQjqjTpqm2KhVdj0a97waD4q2hfarJi0a82H0KLexy2UkN/1S8nt8U0D9gY
# aAdbMGJX+GHgr8n946UlWfzYgoA15/heQGPzz7YtH/mKF0s9Kz8b/24czmQ+m6GB
# aoyf7c8ErU1hTQUL4qpBjw3/gIOCISn3IEf2rQhoVd36YlAO7GgFlfnOH6O97LsZ
# hMsbpdgrVztckkqOnAtLHPqbUxTgKuidPcahUpDSeMuHbZTt+X36Ug+p3aTfqa39
# pnw/jSUTq4aPcFD2pSXrbg6HtpEph+TyEFKC2w/lDNmNysnDZf/OFvkAUoHoNKal
# Eq4nxWFbsGFs+HfJ8uQOzKqzaTbWLlkBP4+0hpp876zcqgJ1GsRQ837iZQ8PBjtT
# JpWU6iDbYCNd6V1zif+W1Ia84U+lV3ZeTPYB/nYAToV+s6clbWRNCq9R3TB/fB0x
# Mz/pYSwpxd2RD2NejB40oYIDIjCCAx4GCSqGSIb3DQEJBjGCAw8wggMLAgEBMGkw
# VTELMAkGA1UEBhMCR0IxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEsMCoGA1UE
# AxMjU2VjdGlnbyBQdWJsaWMgVGltZSBTdGFtcGluZyBDQSBSMzYCEDpSaiyEzlXm
# HWX8zBLY6YkwDQYJYIZIAWUDBAICBQCgeTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcN
# AQcBMBwGCSqGSIb3DQEJBTEPFw0yNDA5MjUyMTQ1MzVaMD8GCSqGSIb3DQEJBDEy
# BDD3xpnP6TSQUp6AW1lNpSnggSlNAJ04h1TAZDss+Pf+ilsE6USW4lrODTlnQKH3
# xRQwDQYJKoZIhvcNAQEBBQAEggIAiDxGnA6KviktU+MAQ4Isg2UGkA96SiaZ7xLE
# J35+UK+UWaLtj90hLqeCf0U0JaVsWpN5Pxu0xi3G8U3EYgc/9qMZ/f1QTdoyfXR3
# 8cquTTRhKz70VSnDOFY8KKtEzwJ3x/eyVzVEa//YYNG1PEOjVMTwOT46pxP2ZZE+
# 5bbcmGSkwOGT0RRFOcSjYnEAsKylfSJ8/ST2fdKAiOr4zvowohV4iQjorHuBBR9F
# 0m3uDaghGgF5APiWE9XgKBcCcZdsqaQEp2nsYQpNy8Z1xmQsPLuE+HXevvElAE5R
# wN3e2wFKCJ0jWDrE83YxcWe8Mu4wJW28OYUzZraecM2tKsHwPUFqmljgELlmQXzL
# phIpD2tSevTiPoJaV8dQgwGVYfZ2Tzdzv9W2quAK64ubxbadRO8Bou5UE0SGMw01
# nGyqfM7oCrWJ/xhDpIcDdsAAYD9gMU7fKGBvPfQsxiFNQAL0Myk5pHUEE700lrz/
# wOm1tz1260veQBPrIlF7F4pDZn8JQS9Kxqk0U4Uj/3e1/BVXU+fWU+9Ma7Si81R6
# qyNrfb1ld0wlfuu+EyylC8A0AfXe+L+Fm90O4TXDwaODByUvVFRh1Pt4BOEEJPaW
# LwMfR4CXmJqQNbMoqL8rj1ovSCkzaT/VNtb5fAH/e1rkBanvTIP04Vrjy89pu2LE
# 4MpKrsc=
# SIG # End signature block
