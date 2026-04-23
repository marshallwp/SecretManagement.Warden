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
                        # Each entry inthe uris array must be a hashtable with both 'uri' and 'match' properties.
                        # Fortuously, "default" is a valid match type, so we can use that when it's missing.
                        if($Secret.uris) {
                            $uris = @()
                            foreach($x in $Secret.uris) {
                                if(($x -is [System.Collections.HashTable]) -and (Test-KeysInHashtable $x -Keys @('uri','match') -MatchAll)) { $uris += $x }
                                elseif($x -is [string]) { $uris += @{uri = $x; match = "default"} }
                                else {
                                    $ex = New-Object System.Management.Automation.PSInvalidCastException "Input [HashTable]Secret could not be cast to any part of a Bitwarden Login."
                                    Write-Error -Exception $ex -Category InvalidOperation -CategoryReason "URIs must be provided as either an array of uris, or an array of hashtables with both a 'uri' and 'match' property." -ErrorAction Stop
                                }
                            }
                            $OldSecret.login.uris = $uris
                        }
                        elseif($IsNewItem) { $OldSecret.login.uris = @() }
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
# MIIsBgYJKoZIhvcNAQcCoIIr9zCCK/MCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDdGkx6LownMkNo
# VbOtdxcJPo+2zPozjvu/Don75HW0+aCCJRowggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# LwYJKoZIhvcNAQkEMSIEIMPCaAs0oonVc0WBXF+0KKpYD9vXETmK1LhAgcGX7NDK
# MA0GCSqGSIb3DQEBAQUABIICAHK7I5R0EPulkDZPSt/4HTaECt+dNEQOhu0c6V+1
# Ywhx+DPd/oc/eOG6lbtgmIcflM/td/t/UwrxSlRpAOGKmmzAeIBGg9iQxw/iolql
# DUSlHp064vgeq0rK5ZcpQXJUWuECTN2tBmbhiDZIcrXaEJS5IVeQnBFWeheNGP4R
# XqKk17ysoU3w3OyHGR2kki3pkOoWb5AgeN5DilRAF8E3bg10ceOJHez8BP3mRP/S
# 9veQWQUoVyG2++qMgE9MrQuSNUhR+S7YbZ86ETNDzVWooEtn0aOBMYQ4+kj1JD/j
# ChFyTe1uDc9noPZLDmFRlynSuwx0wW8xfIFDdmFKTpBfXH8gdHofLpanFc/cNeOW
# GhAl/Xz6Aa+oAr/5wihgGcFpeMVjkmtzMGBOO0AXjEEqCRqo+oX97mBaQRTsDMc7
# DM/STAklvn+KyEsafBSqzTYV8Kuq1N279u+QS/OGXOvUzLDWlRRgf3T4DhB7bPOD
# B52XR8HodksciCx8qk5NM7uRl/ngufyDYz/VkIp5zxHLLEnLl+k2hWR+BKFfRuUY
# mQvhvH3rcps1xQHw7YQxoUZEuBp7YKY5C+T6yBcG4GYl6X5R2P2lQwcJMhfS1M4t
# QO4Qhm4b/NJk8+AYRGcn8K8f537gPyHOLaRQYqrWey+kfeOtK+vhoiDwGXPICs/J
# qSS1oYIDIzCCAx8GCSqGSIb3DQEJBjGCAxAwggMMAgEBMGowVTELMAkGA1UEBhMC
# R0IxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEsMCoGA1UEAxMjU2VjdGlnbyBQ
# dWJsaWMgVGltZSBTdGFtcGluZyBDQSBSMzYCEQCkKTtuHt3XpzQIh616TrckMA0G
# CWCGSAFlAwQCAgUAoHkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG
# 9w0BCQUxDxcNMjYwNDIzMTgzOTExWjA/BgkqhkiG9w0BCQQxMgQwkUmQOJsp1MUu
# c2kGH4sj+cdJcqvxeBk6OvgV/8aUVps6NSOfPzgv0+ylkPw9R+T5MA0GCSqGSIb3
# DQEBAQUABIICAHrAJov34jMODOJta8e464Is/ogLjSTDhxbi50Cnf8HRHcCaAOha
# N9/lOOAgIF+oK+0nrYSEACoYdChyKhL+77iwyUqtO1xlDiYjzM51xBqCxxtYXs/T
# jBS+qRA9uWVq7FU3b3Njau4jd4Ty32OncgMocg1lzUA4qsIFvo0SL8cg2eCz6oRq
# S6qq8xSWMCwJLHUpTxvlcfYMSkOZm1gMsPnyzb7/PzdZt3GtDdSGwA9GZOKO2S2Y
# IyvHjh2SMlSIsahdymqFzR/dkKDufh52OxlL5FPrpFPKZEOg+Q9ExsKzMeSDM8cv
# 6GGnVcCyyMa3XFc5mZBFq9w43I1+YM33C9z1xqdoFMALOJP6p8mJmhirAuKFbliX
# Mrovoe9dZK73WtBv4ZprL60eikXxWjsHZalOJdgn5DeILM52Is5bndummQUcxLPy
# RNQqu0cE2yDL10XuVmN4Nk/5pdxZM++z+HphAaH5BNDLlWBzM2F8LSNhkhI9DWOX
# 0wivNflcwx6S3tQqV4aSbUxdBcRHmvtYGvGS1mwWUXLuqW3m2tF14alfFSd9VWIu
# xp4HMPghtgTm7sjytQdvWUHjWDSmru67fc561TPJPhmhaM+ybVCmjlooaTY2SOPG
# rRA4t+pDZMaZc86KSuVdLhcBw3a/+tWbzL9jbAthWwX5sAY1XiBta38R
# SIG # End signature block
