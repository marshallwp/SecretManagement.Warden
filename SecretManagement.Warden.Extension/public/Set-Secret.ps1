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
    if( ! $OldSecret ) {
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
                        Write-Error -Exception $ex -Category InvalidOperation -CategoryReason "Hashtable contains neither UserName nor Password." -ErrorAction Stop
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
                            if($_ -ine "URIs") { $OldSecret.login.$_ = $null } else { $OldSecret.logon.uris = $() }
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
                    switch($ExportObjectsToSecureNotesAs) {
                        "CliXml" {
                            $tmp = New-TemporaryFile
                            $Secret | Export-Clixml -Depth $MaximumObjectDepth -Path $tmp
                            $OldSecret.notes = $ObjTemplate -f "CliXml", (Get-Content -Path $tmp -Raw)
                            Remove-Item $tmp -Force
                            break
                        }
                        "JSON" {
                            $OldSecret.notes = $ObjTemplate -f "JSON", ($Secret | ConvertTo-Json -Depth $MaximumObjectDepth -Compress)
                            break
                        }
                        default {
                            $ex = New-Object System.NotSupportedException "$ExportObjectsToSecureNotesAs is not a supported means of representing a PowerShell Object."
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
                    if ( Test-KeysInHashtable $Secret.Keys $identFields ) {
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
                else { [System.Collections.Generic.List[string]]$CmdParams = @("edit","item"); $CmdParams.Add($Name) }

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
# MIIm/wYJKoZIhvcNAQcCoIIm8DCCJuwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUt2qm1ca2m7ZI58kVvoNWb8ZM
# DBOggiAQMIIFbzCCBFegAwIBAgIQSPyTtGBVlI02p8mKidaUFjANBgkqhkiG9w0B
# AQwFADB7MQswCQYDVQQGEwJHQjEbMBkGA1UECAwSR3JlYXRlciBNYW5jaGVzdGVy
# MRAwDgYDVQQHDAdTYWxmb3JkMRowGAYDVQQKDBFDb21vZG8gQ0EgTGltaXRlZDEh
# MB8GA1UEAwwYQUFBIENlcnRpZmljYXRlIFNlcnZpY2VzMB4XDTIxMDUyNTAwMDAw
# MFoXDTI4MTIzMTIzNTk1OVowVjELMAkGA1UEBhMCR0IxGDAWBgNVBAoTD1NlY3Rp
# Z28gTGltaXRlZDEtMCsGA1UEAxMkU2VjdGlnbyBQdWJsaWMgQ29kZSBTaWduaW5n
# IFJvb3QgUjQ2MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAjeeUEiIE
# JHQu/xYjApKKtq42haxH1CORKz7cfeIxoFFvrISR41KKteKW3tCHYySJiv/vEpM7
# fbu2ir29BX8nm2tl06UMabG8STma8W1uquSggyfamg0rUOlLW7O4ZDakfko9qXGr
# YbNzszwLDO/bM1flvjQ345cbXf0fEj2CA3bm+z9m0pQxafptszSswXp43JJQ8mTH
# qi0Eq8Nq6uAvp6fcbtfo/9ohq0C/ue4NnsbZnpnvxt4fqQx2sycgoda6/YDnAdLv
# 64IplXCN/7sVz/7RDzaiLk8ykHRGa0c1E3cFM09jLrgt4b9lpwRrGNhx+swI8m2J
# mRCxrds+LOSqGLDGBwF1Z95t6WNjHjZ/aYm+qkU+blpfj6Fby50whjDoA7NAxg0P
# OM1nqFOI+rgwZfpvx+cdsYN0aT6sxGg7seZnM5q2COCABUhA7vaCZEao9XOwBpXy
# bGWfv1VbHJxXGsd4RnxwqpQbghesh+m2yQ6BHEDWFhcp/FycGCvqRfXvvdVnTyhe
# Be6QTHrnxvTQ/PrNPjJGEyA2igTqt6oHRpwNkzoJZplYXCmjuQymMDg80EY2NXyc
# uu7D1fkKdvp+BRtAypI16dV60bV/AK6pkKrFfwGcELEW/MxuGNxvYv6mUKe4e7id
# FT/+IAx1yCJaE5UZkADpGtXChvHjjuxf9OUCAwEAAaOCARIwggEOMB8GA1UdIwQY
# MBaAFKARCiM+lvEH7OKvKe+CpX/QMKS0MB0GA1UdDgQWBBQy65Ka/zWWSC8oQEJw
# IDaRXBeF5jAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zATBgNVHSUE
# DDAKBggrBgEFBQcDAzAbBgNVHSAEFDASMAYGBFUdIAAwCAYGZ4EMAQQBMEMGA1Ud
# HwQ8MDowOKA2oDSGMmh0dHA6Ly9jcmwuY29tb2RvY2EuY29tL0FBQUNlcnRpZmlj
# YXRlU2VydmljZXMuY3JsMDQGCCsGAQUFBwEBBCgwJjAkBggrBgEFBQcwAYYYaHR0
# cDovL29jc3AuY29tb2RvY2EuY29tMA0GCSqGSIb3DQEBDAUAA4IBAQASv6Hvi3Sa
# mES4aUa1qyQKDKSKZ7g6gb9Fin1SB6iNH04hhTmja14tIIa/ELiueTtTzbT72ES+
# BtlcY2fUQBaHRIZyKtYyFfUSg8L54V0RQGf2QidyxSPiAjgaTCDi2wH3zUZPJqJ8
# ZsBRNraJAlTH/Fj7bADu/pimLpWhDFMpH2/YGaZPnvesCepdgsaLr4CnvYFIUoQx
# 2jLsFeSmTD1sOXPUC4U5IOCFGmjhp0g4qdE2JXfBjRkWxYhMZn0vY86Y6GnfrDyo
# XZ3JHFuu2PMvdM+4fvbXg50RlmKarkUT2n/cR/vfw1Kf5gZV6Z2M8jpiUbzsJA8p
# 1FiAhORFe1rYMIIGGjCCBAKgAwIBAgIQYh1tDFIBnjuQeRUgiSEcCjANBgkqhkiG
# 9w0BAQwFADBWMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVk
# MS0wKwYDVQQDEyRTZWN0aWdvIFB1YmxpYyBDb2RlIFNpZ25pbmcgUm9vdCBSNDYw
# HhcNMjEwMzIyMDAwMDAwWhcNMzYwMzIxMjM1OTU5WjBUMQswCQYDVQQGEwJHQjEY
# MBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSswKQYDVQQDEyJTZWN0aWdvIFB1Ymxp
# YyBDb2RlIFNpZ25pbmcgQ0EgUjM2MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIB
# igKCAYEAmyudU/o1P45gBkNqwM/1f/bIU1MYyM7TbH78WAeVF3llMwsRHgBGRmxD
# eEDIArCS2VCoVk4Y/8j6stIkmYV5Gej4NgNjVQ4BYoDjGMwdjioXan1hlaGFt4Wk
# 9vT0k2oWJMJjL9G//N523hAm4jF4UjrW2pvv9+hdPX8tbbAfI3v0VdJiJPFy/7Xw
# iunD7mBxNtecM6ytIdUlh08T2z7mJEXZD9OWcJkZk5wDuf2q52PN43jc4T9OkoXZ
# 0arWZVeffvMr/iiIROSCzKoDmWABDRzV/UiQ5vqsaeFaqQdzFf4ed8peNWh1OaZX
# nYvZQgWx/SXiJDRSAolRzZEZquE6cbcH747FHncs/Kzcn0Ccv2jrOW+LPmnOyB+t
# AfiWu01TPhCr9VrkxsHC5qFNxaThTG5j4/Kc+ODD2dX/fmBECELcvzUHf9shoFvr
# n35XGf2RPaNTO2uSZ6n9otv7jElspkfK9qEATHZcodp+R4q2OIypxR//YEb3fkDn
# 3UayWW9bAgMBAAGjggFkMIIBYDAfBgNVHSMEGDAWgBQy65Ka/zWWSC8oQEJwIDaR
# XBeF5jAdBgNVHQ4EFgQUDyrLIIcouOxvSK4rVKYpqhekzQwwDgYDVR0PAQH/BAQD
# AgGGMBIGA1UdEwEB/wQIMAYBAf8CAQAwEwYDVR0lBAwwCgYIKwYBBQUHAwMwGwYD
# VR0gBBQwEjAGBgRVHSAAMAgGBmeBDAEEATBLBgNVHR8ERDBCMECgPqA8hjpodHRw
# Oi8vY3JsLnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNDb2RlU2lnbmluZ1Jvb3RS
# NDYuY3JsMHsGCCsGAQUFBwEBBG8wbTBGBggrBgEFBQcwAoY6aHR0cDovL2NydC5z
# ZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljQ29kZVNpZ25pbmdSb290UjQ2LnA3YzAj
# BggrBgEFBQcwAYYXaHR0cDovL29jc3Auc2VjdGlnby5jb20wDQYJKoZIhvcNAQEM
# BQADggIBAAb/guF3YzZue6EVIJsT/wT+mHVEYcNWlXHRkT+FoetAQLHI1uBy/YXK
# ZDk8+Y1LoNqHrp22AKMGxQtgCivnDHFyAQ9GXTmlk7MjcgQbDCx6mn7yIawsppWk
# vfPkKaAQsiqaT9DnMWBHVNIabGqgQSGTrQWo43MOfsPynhbz2Hyxf5XWKZpRvr3d
# MapandPfYgoZ8iDL2OR3sYztgJrbG6VZ9DoTXFm1g0Rf97Aaen1l4c+w3DC+IkwF
# kvjFV3jS49ZSc4lShKK6BrPTJYs4NG1DGzmpToTnwoqZ8fAmi2XlZnuchC4NPSZa
# PATHvNIzt+z1PHo35D/f7j2pO1S8BCysQDHCbM5Mnomnq5aYcKCsdbh0czchOm8b
# kinLrYrKpii+Tk7pwL7TjRKLXkomm5D1Umds++pip8wH2cQpf93at3VDcOK4N7Ew
# oIJB0kak6pSzEu4I64U6gZs7tS/dGNSljf2OSSnRr7KWzq03zl8l75jy+hOds9TW
# SenLbjBQUGR96cFr6lEUfAIEHVC1L68Y1GGxx4/eRI82ut83axHMViw1+sVpbPxg
# 51Tbnio1lB93079WPFnYaOvfGAA0e0zcfF/M9gXr+korwQTh2Prqooq2bYNMvUoU
# KD85gnJ+t0smrWrb8dee2CvYZXD5laGtaAxOfy/VKNmwuWuAh9kcMIIGkjCCBPqg
# AwIBAgIRAPQbCCfcuboB1FpiBQ3KD8gwDQYJKoZIhvcNAQEMBQAwVDELMAkGA1UE
# BhMCR0IxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDErMCkGA1UEAxMiU2VjdGln
# byBQdWJsaWMgQ29kZSBTaWduaW5nIENBIFIzNjAeFw0yMjAzMjMwMDAwMDBaFw0y
# NTAzMjIyMzU5NTlaMH4xCzAJBgNVBAYTAlVTMQ4wDAYDVQQIDAVUZXhhczEoMCYG
# A1UECgwfSW5kdXN0cmlhbCBJbmZvIFJlc291cmNlcywgSW5jLjELMAkGA1UECwwC
# SVQxKDAmBgNVBAMMH0luZHVzdHJpYWwgSW5mbyBSZXNvdXJjZXMsIEluYy4wggIi
# MA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCexO4utoQjoEC5xfsGWaPEX5eH
# S6JQKcXPsQ+nG15pO+u4SGf3Oz/kApi7GRqmmQSk/qQc9hynIb4tyNQagDZD2vWq
# 59jGE0UGdSOeyCZmW/08IMm1MSrYsmcY2I8O+IkZnEXgmudmcr+03rYQEf7+coAK
# TPB8woFqKmvfyFhnEUqRylhx3CDZizvwzv/AVw/d0/Xwn0XWOC+vR9kG0JDYdJcn
# tUE6f+9FQ7taPN7HVnhq1yYQmb6WZRHhIFFBBtjOc8Ca+EaNmRFQEwgKdwT7f9q4
# 54hodmaLO8g9vtVpqzoEwWFcPyvmJNuuc44RdGrK+xJOH61mnHD44gWFgsQw7yyp
# +4TH0D/BUw/qszALFpbNmZ9OUdYB67bZWfIG2GkFzWjmBYSmresNuXprw/bCTxRS
# VWQr56fT8/nykIRIan31njGQSxXZUKCyLw5ISVrPfo256MIrbtCipZNHZIkFS2FC
# EKYj0YTxmiSrHMh8wEPOww9zsf+kv0xoTSRTDN4Rbr0Z2mdj9dnFbx5g/DqlUsA4
# ULJdNRYPFYqBq3dAcYDT+W1ok8/njEQoX9KNyVaY/Tq7c+rHU8ACYBPA3fCJvubE
# UVnwR0Tkt7AkeaYGBCXZjTAEXGwO7XnHSittHj/gJMh+LfB3r8d4TCoUuJ2QK1P5
# AhOJxoQL9J+P64h1pwIDAQABo4IBszCCAa8wHwYDVR0jBBgwFoAUDyrLIIcouOxv
# SK4rVKYpqhekzQwwHQYDVR0OBBYEFH7pA0S7pJ9K6XVNS8eaMnR6ycgqMA4GA1Ud
# DwEB/wQEAwIHgDAMBgNVHRMBAf8EAjAAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMEoG
# A1UdIARDMEEwNQYMKwYBBAGyMQECAQMCMCUwIwYIKwYBBQUHAgEWF2h0dHBzOi8v
# c2VjdGlnby5jb20vQ1BTMAgGBmeBDAEEATBJBgNVHR8EQjBAMD6gPKA6hjhodHRw
# Oi8vY3JsLnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNDb2RlU2lnbmluZ0NBUjM2
# LmNybDB5BggrBgEFBQcBAQRtMGswRAYIKwYBBQUHMAKGOGh0dHA6Ly9jcnQuc2Vj
# dGlnby5jb20vU2VjdGlnb1B1YmxpY0NvZGVTaWduaW5nQ0FSMzYuY3J0MCMGCCsG
# AQUFBzABhhdodHRwOi8vb2NzcC5zZWN0aWdvLmNvbTAoBgNVHREEITAfgR1ob3N0
# bWFzdGVyQGluZHVzdHJpYWxpbmZvLmNvbTANBgkqhkiG9w0BAQwFAAOCAYEAV7fn
# nHWtFSsqLXfqTEB0da/OJccOND+vzQA29eD+PKdIkGKBVwTZsqt5Brb+FRWFUg4o
# rv/Nt58be2Zv9CbQTdlnC5retWRC6dtzfjMTADEr64kPjxjEl3YsfMN2mNwCQAlD
# NPoJsp6k1acIbGQZIcTJV9DqXhTb+lX6ALy6OazWecA9CsJRUxIndVojkCJhxzgu
# 5JECLo+jzpK28vbpA8GwyMEQ4MKWRIpNiuSbQ//pCgSCtWa7OoPJ51T0vr47+PeL
# w2QUelwq3LeB6wCX3VPgoe/3E5aOAxuDHj6RMDFJpfxiELFPLjqpH/d9k1usJtaB
# ejxodJsrDFWfXnvggYi91sGerldssmdvpNvsEK+B2jNuDj6eq9bmxqwMHJcnRSwc
# yOnG8XEc2pHDyehJbkNxXWcsgdkv0vclk4v/zCBbBW5ssIYa9DKx+m8FOMz87mDh
# VU76+hJPwrvGbBBZ3mf+0/ChIKA0pi91xEneimC1pMzID1qphmUx5s2W2l8yMIIG
# 7DCCBNSgAwIBAgIQMA9vrN1mmHR8qUY2p3gtuTANBgkqhkiG9w0BAQwFADCBiDEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNl
# eSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMT
# JVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMTkwNTAy
# MDAwMDAwWhcNMzgwMTE4MjM1OTU5WjB9MQswCQYDVQQGEwJHQjEbMBkGA1UECBMS
# R3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxmb3JkMRgwFgYDVQQKEw9T
# ZWN0aWdvIExpbWl0ZWQxJTAjBgNVBAMTHFNlY3RpZ28gUlNBIFRpbWUgU3RhbXBp
# bmcgQ0EwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDIGwGv2Sx+iJl9
# AZg/IJC9nIAhVJO5z6A+U++zWsB21hoEpc5Hg7XrxMxJNMvzRWW5+adkFiYJ+9Uy
# UnkuyWPCE5u2hj8BBZJmbyGr1XEQeYf0RirNxFrJ29ddSU1yVg/cyeNTmDoqHvzO
# WEnTv/M5u7mkI0Ks0BXDf56iXNc48RaycNOjxN+zxXKsLgp3/A2UUrf8H5VzJD0B
# KLwPDU+zkQGObp0ndVXRFzs0IXuXAZSvf4DP0REKV4TJf1bgvUacgr6Unb+0ILBg
# frhN9Q0/29DqhYyKVnHRLZRMyIw80xSinL0m/9NTIMdgaZtYClT0Bef9Maz5yIUX
# x7gpGaQpL0bj3duRX58/Nj4OMGcrRrc1r5a+2kxgzKi7nw0U1BjEMJh0giHPYla1
# IXMSHv2qyghYh3ekFesZVf/QOVQtJu5FGjpvzdeE8NfwKMVPZIMC1Pvi3vG8Aij0
# bdonigbSlofe6GsO8Ft96XZpkyAcSpcsdxkrk5WYnJee647BeFbGRCXfBhKaBi2f
# A179g6JTZ8qx+o2hZMmIklnLqEbAyfKm/31X2xJ2+opBJNQb/HKlFKLUrUMcpEmL
# QTkUAx4p+hulIq6lw02C0I3aa7fb9xhAV3PwcaP7Sn1FNsH3jYL6uckNU4B9+rY5
# WDLvbxhQiddPnTO9GrWdod6VQXqngwIDAQABo4IBWjCCAVYwHwYDVR0jBBgwFoAU
# U3m/WqorSs9UgOHYm8Cd8rIDZsswHQYDVR0OBBYEFBqh+GEZIA/DQXdFKI7RNV8G
# EgRVMA4GA1UdDwEB/wQEAwIBhjASBgNVHRMBAf8ECDAGAQH/AgEAMBMGA1UdJQQM
# MAoGCCsGAQUFBwMIMBEGA1UdIAQKMAgwBgYEVR0gADBQBgNVHR8ESTBHMEWgQ6BB
# hj9odHRwOi8vY3JsLnVzZXJ0cnVzdC5jb20vVVNFUlRydXN0UlNBQ2VydGlmaWNh
# dGlvbkF1dGhvcml0eS5jcmwwdgYIKwYBBQUHAQEEajBoMD8GCCsGAQUFBzAChjNo
# dHRwOi8vY3J0LnVzZXJ0cnVzdC5jb20vVVNFUlRydXN0UlNBQWRkVHJ1c3RDQS5j
# cnQwJQYIKwYBBQUHMAGGGWh0dHA6Ly9vY3NwLnVzZXJ0cnVzdC5jb20wDQYJKoZI
# hvcNAQEMBQADggIBAG1UgaUzXRbhtVOBkXXfA3oyCy0lhBGysNsqfSoF9bw7J/Ra
# oLlJWZApbGHLtVDb4n35nwDvQMOt0+LkVvlYQc/xQuUQff+wdB+PxlwJ+TNe6qAc
# Jlhc87QRD9XVw+K81Vh4v0h24URnbY+wQxAPjeT5OGK/EwHFhaNMxcyyUzCVpNb0
# llYIuM1cfwGWvnJSajtCN3wWeDmTk5SbsdyybUFtZ83Jb5A9f0VywRsj1sJVhGbk
# s8VmBvbz1kteraMrQoohkv6ob1olcGKBc2NeoLvY3NdK0z2vgwY4Eh0khy3k/ALW
# PncEvAQ2ted3y5wujSMYuaPCRx3wXdahc1cFaJqnyTdlHb7qvNhCg0MFpYumCf/R
# oZSmTqo9CfUFbLfSZFrYKiLCS53xOV5M3kg9mzSWmglfjv33sVKRzj+J9hyhtal1
# H3G/W0NdZT1QgW6r8NDT/LKzH7aZlib0PHmLXGTMze4nmuWgwAxyh8FuTVrTHurw
# ROYybxzrF06Uw3hlIDsPQaof6aFBnf6xuKBlKjTg3qj5PObBMLvAoGMs/FwWAKjQ
# xH/qEZ0eBsambTJdtDgJK0kHqv3sMNrxpy/Pt/360KOE2See+wFmd7lWEOEgbsau
# sfm2usg1XTN2jvF8IAwqd661ogKGuinutFoAsYyr4/kKyVRd1LlqdJ69SK6YMIIG
# 9TCCBN2gAwIBAgIQOUwl4XygbSeoZeI72R0i1DANBgkqhkiG9w0BAQwFADB9MQsw
# CQYDVQQGEwJHQjEbMBkGA1UECBMSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQH
# EwdTYWxmb3JkMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxJTAjBgNVBAMTHFNl
# Y3RpZ28gUlNBIFRpbWUgU3RhbXBpbmcgQ0EwHhcNMjMwNTAzMDAwMDAwWhcNMzQw
# ODAyMjM1OTU5WjBqMQswCQYDVQQGEwJHQjETMBEGA1UECBMKTWFuY2hlc3RlcjEY
# MBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSwwKgYDVQQDDCNTZWN0aWdvIFJTQSBU
# aW1lIFN0YW1waW5nIFNpZ25lciAjNDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCC
# AgoCggIBAKSTKFJLzyeHdqQpHJk4wOcO1NEc7GjLAWTkis13sHFlgryf/Iu7u5WY
# +yURjlqICWYRFFiyuiJb5vYy8V0twHqiDuDgVmTtoeWBIHIgZEFsx8MI+vN9Xe8h
# msJ+1yzDuhGYHvzTIAhCs1+/f4hYMqsws9iMepZKGRNcrPznq+kcFi6wsDiVSs+F
# UKtnAyWhuzjpD2+pWpqRKBM1uR/zPeEkyGuxmegN77tN5T2MVAOR0Pwtz1UzOHoJ
# HAfRIuBjhqe+/dKDcxIUm5pMCUa9NLzhS1B7cuBb/Rm7HzxqGXtuuy1EKr48TMys
# igSTxleGoHM2K4GX+hubfoiH2FJ5if5udzfXu1Cf+hglTxPyXnypsSBaKaujQod3
# 4PRMAkjdWKVTpqOg7RmWZRUpxe0zMCXmloOBmvZgZpBYB4DNQnWs+7SR0MXdAUBq
# tqgQ7vaNereeda/TpUsYoQyfV7BeJUeRdM11EtGcb+ReDZvsdSbu/tP1ki9Sheja
# RFEqoswAyodmQ6MbAO+itZadYq0nC/IbSsnDlEI3iCCEqIeuw7ojcnv4VO/4ayew
# hfWnQ4XYKzl021p3AtGk+vXNnD3MH65R0Hts2B0tEUJTcXTC5TWqLVIS2SXP8NPQ
# kUMS1zJ9mGzjd0HI/x8kVO9urcY+VXvxXIc6ZPFgSwVP77kv7AkTAgMBAAGjggGC
# MIIBfjAfBgNVHSMEGDAWgBQaofhhGSAPw0F3RSiO0TVfBhIEVTAdBgNVHQ4EFgQU
# Aw8xyJEqk71j89FdTaQ0D9KVARgwDgYDVR0PAQH/BAQDAgbAMAwGA1UdEwEB/wQC
# MAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwSgYDVR0gBEMwQTA1BgwrBgEEAbIx
# AQIBAwgwJTAjBggrBgEFBQcCARYXaHR0cHM6Ly9zZWN0aWdvLmNvbS9DUFMwCAYG
# Z4EMAQQCMEQGA1UdHwQ9MDswOaA3oDWGM2h0dHA6Ly9jcmwuc2VjdGlnby5jb20v
# U2VjdGlnb1JTQVRpbWVTdGFtcGluZ0NBLmNybDB0BggrBgEFBQcBAQRoMGYwPwYI
# KwYBBQUHMAKGM2h0dHA6Ly9jcnQuc2VjdGlnby5jb20vU2VjdGlnb1JTQVRpbWVT
# dGFtcGluZ0NBLmNydDAjBggrBgEFBQcwAYYXaHR0cDovL29jc3Auc2VjdGlnby5j
# b20wDQYJKoZIhvcNAQEMBQADggIBAEybZVj64HnP7xXDMm3eM5Hrd1ji673LSjx1
# 3n6UbcMixwSV32VpYRMM9gye9YkgXsGHxwMkysel8Cbf+PgxZQ3g621RV6aMhFII
# Rhwqwt7y2opF87739i7Efu347Wi/elZI6WHlmjl3vL66kWSIdf9dhRY0J9Ipy//t
# Ldr/vpMM7G2iDczD8W69IZEaIwBSrZfUYngqhHmo1z2sIY9wwyR5OpfxDaOjW1PY
# qwC6WPs1gE9fKHFsGV7Cg3KQruDG2PKZ++q0kmV8B3w1RB2tWBhrYvvebMQKqWzT
# IUZw3C+NdUwjwkHQepY7w0vdzZImdHZcN6CaJJ5OX07Tjw/lE09ZRGVLQ2TPSPhn
# Z7lNv8wNsTow0KE9SK16ZeTs3+AB8LMqSjmswaT5qX010DJAoLEZKhghssh9BXEa
# Syc2quCYHIN158d+S4RDzUP7kJd2KhKsQMFwW5kKQPqAbZRhe8huuchnZyRcUI0B
# IN4H9wHU+C4RzZ2D5fjKJRxEPSflsIZHKgsbhHZ9e2hPjbf3E7TtoC3ucw/ZELqd
# mSx813UfjxDElOZ+JOWVSoiMJ9aFZh35rmR2kehI/shVCu0pwx/eOKbAFPsyPfip
# g2I2yMO+AIccq/pKQhyJA9z1XHxw2V14Tu6fXiDmCWp8KwijSPUV/ARP380hHHrl
# 9Y4a1LlAMYIGWTCCBlUCAQEwaTBUMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2Vj
# dGlnbyBMaW1pdGVkMSswKQYDVQQDEyJTZWN0aWdvIFB1YmxpYyBDb2RlIFNpZ25p
# bmcgQ0EgUjM2AhEA9BsIJ9y5ugHUWmIFDcoPyDAJBgUrDgMCGgUAoHgwGAYKKwYB
# BAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAc
# BgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUeU8K
# c4gf2nln7SfQEwQfV4lqRf4wDQYJKoZIhvcNAQEBBQAEggIAFw36Ii3J7/Atb9cH
# gi5OKivIZFzDHYfc2D3JbA0qbdcqvM0iMLz7zNUnseIjjRWzDhbQXN06Q4RaqWE7
# 3HfksZzg/22g+MaFrE8PHJt0GKsxd1/K2BMVh+yUNvdsNGRl+j2zDXDWTpRkRqVM
# PYnpFLrAnCuNFadPSumNYu4gHTY7gRHGNAsoDqSZjg72RER6AK4/53J99VKYGy7s
# XBDTOaynzX4sUTb5tJzIGntiwl2AxebUOZoahxG/AQlAZA0hDIVKcVB1NQlzdeDr
# wglP/dAikhnSxcZQdDG43LkTZ/KZh7pysPL4EafJUugJNfv1kkClcuD4qPs+EqwW
# wqsdZHaE5KuhbGOP/7jCvl9HTtliiXL2FTsR4k2mOQYUFI8J4NZM64/lKWnqp19A
# 3Is9wageD0DUtuZLtEUDWNK/9sGSK/s/yYZI8MefOwseQFkFdh7buDi4mWud31jd
# SVEoIV7IGSUm9oqMtRr4ScUgjdoDEWGN5+ttXXxe3/LwFB7/FT/A192TvBBfHI6o
# RehjDDxGEl9gSJRsxHAGFU2GBlO6b5KDWaWh1W5/WFYTWVYs6otaErkxD15GBgQd
# ktm1Wn84WSKawimNVdW6T2XMA7Mbf8u9Eeeu6JUzlsyS3Ta7A4OyQR8aFgd0AQFB
# aYdwFQaXGzA90runyDJCldk2NUWhggNLMIIDRwYJKoZIhvcNAQkGMYIDODCCAzQC
# AQEwgZEwfTELMAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3Rl
# cjEQMA4GA1UEBxMHU2FsZm9yZDEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSUw
# IwYDVQQDExxTZWN0aWdvIFJTQSBUaW1lIFN0YW1waW5nIENBAhA5TCXhfKBtJ6hl
# 4jvZHSLUMA0GCWCGSAFlAwQCAgUAoHkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEH
# ATAcBgkqhkiG9w0BCQUxDxcNMjMwOTI5MTkwNjAwWjA/BgkqhkiG9w0BCQQxMgQw
# bePnTd6j6jx52L1WhCQQQRfMlxXnrCwEXPQk8bJdn6K1YXT+qQx+CAu2bwP6Ezk4
# MA0GCSqGSIb3DQEBAQUABIICACQ4XTqaLQtGUzVNjDc1Yvu4+ElFXSYN93kMnh3s
# l/Uz95COgSWGjG3IgYU15vwvyKnzv3GORkr5T5Nj4s+LVpGetI5DJA1U/mp3lLP+
# zXtcF3jNBIDBMRAlITUAxOhtpZVxwKk+hOzbubb17oaRcD9TRbINZyba5ClSg44V
# 9/RlA5K901zEoH+3l5IYO9tJX/d5+SGdEMhp14R25fs5AWaczPR5mSYIF8an5fHT
# 7SYZaMATd1yUGgmfTFA7E3xKn8dZIBGyR44KxVHhZfYOWMzPOhPtsBfHHxk/fwzh
# 0BurEIsBYrHbG+kpadXJ2Sopj3IaqEtkQaKzQySK0azcADozTsIbX7ywfAchB9c/
# 6W+gA6d8NqUYcU/g/BhpUN3T0Lab1F+ay7Y/QiJfEDZ55uLNWJe8PwyoFIElZ4p/
# qrHZNTgczswWzXOTQJJasZUZVpdg1qX653WnrM9DyJ5fX8JX8D3BxPakNvg4VhQ2
# niN3CnkVOHHD+i+PVKAu5REF2N6itgGedd1HIvR5Ls+wahf4wfFpEN14GrHoU/Jz
# OE+464lFY4nhx1S3aa1VYSOlFAe1eY+sNQybCeSMcZbBUUvqambRwXZFW2tmbvov
# 7MLGLmVQMF45OFmPhhdFB5gOvEW3ZoMlfOKIuKBGJ+1O6QJye3vzj1dFX0Eolcfa
# 5bx/
# SIG # End signature block
