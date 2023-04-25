<#
.SYNOPSIS
    Retrieves metadata about one or more secrets.  Can be piped to Get-Secret.
.DESCRIPTION
    Retrieves metadata about one or more secrets matching the filter.
.NOTES
    Per SecretManagement documentation, "The Get-SecretInfo cmdlet writes an array of Microsoft.PowerShell.SecretManagement.SecretInformation type objects to the output pipeline or an empty array if no matches were found."
#>
function Get-SecretInfo {
    [CmdletBinding()]
    param(
        [Alias('Name')][string] $Filter,
        [Alias('Vault')][string] $VaultName,
        [hashtable] $AdditionalParameters
    )

    # Enable Verbose Mode inside this script if passed from the wrapper.
    if($AdditionalParameters.ContainsKey('Verbose') -and ($AdditionalParameters['Verbose'] -eq $true)) {$script:VerbosePreference = 'Continue'}
    $AdditionalParameters = Merge-Defaults $AdditionalParameters
    Sync-BitwardenVault $AdditionalParameters.ResyncCacheIfOlderThan

    [System.Collections.Generic.List[string]]$CmdParams = @( "list", "items" )

    if ( $Filter ) {
        $CmdParams.Add( '--search' )
        $CmdParams.Add( $Filter )
    }

    if ( $AdditionalParameters.ContainsKey('organizationid')) {
        $CmdParams.Add( '--organizationid' )
        $CmdParams.Add( $AdditionalParameters['organizationid'] )
    }

    $Results = Invoke-BitwardenCLI @CmdParams

    foreach ( $secretInfo in $Results ) {
        if ( $secretInfo.type -eq [BitwardenItemType]::SecureNote -and !($Result.notes | Select-String -Pattern "(?<=PowerShellObjectRepresentation: )[^\n]*") ) {
            $type = [Microsoft.PowerShell.SecretManagement.SecretType]::SecureString
        }
        else {
            $type = [Microsoft.PowerShell.SecretManagement.SecretType]::Hashtable
        }

        $hashtable = [ordered]@{}
        if($secretInfo.login) { $hashtable['username'] = $secretInfo.login.username }
        foreach( $property in ($secretInfo | Select-Object -ExcludeProperty notes,login,id,type | Get-Member -MemberType NoteProperty).Name ) {
            $hashtable[$property] = $secretInfo.$property
        }

        [Microsoft.PowerShell.SecretManagement.SecretInformation]::new(
            $secretInfo.id,
            $type,
            $VaultName,
            $hashtable
        )
    }
}

# SIG # Begin signature block
# MIInAQYJKoZIhvcNAQcCoIIm8jCCJu4CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUcxPgdOKKwoODhmJTwcYSzpJp
# UGGggiARMIIFbzCCBFegAwIBAgIQSPyTtGBVlI02p8mKidaUFjANBgkqhkiG9w0B
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
# 9jCCBN6gAwIBAgIRAJA5f5rSSjoT8r2RXwg4qUMwDQYJKoZIhvcNAQEMBQAwfTEL
# MAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UE
# BxMHU2FsZm9yZDEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSUwIwYDVQQDExxT
# ZWN0aWdvIFJTQSBUaW1lIFN0YW1waW5nIENBMB4XDTIyMDUxMTAwMDAwMFoXDTMz
# MDgxMDIzNTk1OVowajELMAkGA1UEBhMCR0IxEzARBgNVBAgTCk1hbmNoZXN0ZXIx
# GDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEsMCoGA1UEAwwjU2VjdGlnbyBSU0Eg
# VGltZSBTdGFtcGluZyBTaWduZXIgIzMwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAw
# ggIKAoICAQCQsnE/eeHUuYoXzMOXwpCUcu1aOm8BQ39zWiifJHygNUAG+pSvCqGD
# thPkSxUGXmqKIDRxe7slrT9bCqQfL2x9LmFR0IxZNz6mXfEeXYC22B9g480Saogf
# xv4Yy5NDVnrHzgPWAGQoViKxSxnS8JbJRB85XZywlu1aSY1+cuRDa3/JoD9sSq3V
# AE+9CriDxb2YLAd2AXBF3sPwQmnq/ybMA0QfFijhanS2nEX6tjrOlNEfvYxlqv38
# wzzoDZw4ZtX8fR6bWYyRWkJXVVAWDUt0cu6gKjH8JgI0+WQbWf3jOtTouEEpdAE/
# DeATdysRPPs9zdDn4ZdbVfcqA23VzWLazpwe/OpwfeZ9S2jOWilh06BcJbOlJ2ij
# WP31LWvKX2THaygM2qx4Qd6S7w/F7KvfLW8aVFFsM7ONWWDn3+gXIqN5QWLP/Hvz
# ktqu4DxPD1rMbt8fvCKvtzgQmjSnC//+HV6k8+4WOCs/rHaUQZ1kHfqA/QDh/vg6
# 1MNeu2lNcpnl8TItUfphrU3qJo5t/KlImD7yRg1psbdu9AXbQQXGGMBQ5Pit/qxj
# YUeRvEa1RlNsxfThhieThDlsdeAdDHpZiy7L9GQsQkf0VFiFN+XHaafSJYuWv8at
# 4L2xN/cf30J7qusc6es9Wt340pDVSZo6HYMaV38cAcLOHH3M+5YVxQIDAQABo4IB
# gjCCAX4wHwYDVR0jBBgwFoAUGqH4YRkgD8NBd0UojtE1XwYSBFUwHQYDVR0OBBYE
# FCUuaDxrmiskFKkfot8mOs8UpvHgMA4GA1UdDwEB/wQEAwIGwDAMBgNVHRMBAf8E
# AjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMEoGA1UdIARDMEEwNQYMKwYBBAGy
# MQECAQMIMCUwIwYIKwYBBQUHAgEWF2h0dHBzOi8vc2VjdGlnby5jb20vQ1BTMAgG
# BmeBDAEEAjBEBgNVHR8EPTA7MDmgN6A1hjNodHRwOi8vY3JsLnNlY3RpZ28uY29t
# L1NlY3RpZ29SU0FUaW1lU3RhbXBpbmdDQS5jcmwwdAYIKwYBBQUHAQEEaDBmMD8G
# CCsGAQUFBzAChjNodHRwOi8vY3J0LnNlY3RpZ28uY29tL1NlY3RpZ29SU0FUaW1l
# U3RhbXBpbmdDQS5jcnQwIwYIKwYBBQUHMAGGF2h0dHA6Ly9vY3NwLnNlY3RpZ28u
# Y29tMA0GCSqGSIb3DQEBDAUAA4ICAQBz2u1ocsvCuUChMbu0A6MtFHsk57RbFX2o
# 6f2t0ZINfD02oGnZ85ow2qxp1nRXJD9+DzzZ9cN5JWwm6I1ok87xd4k5f6gEBdo0
# wxTqnwhUq//EfpZsK9OU67Rs4EVNLLL3OztatcH714l1bZhycvb3Byjz07LQ6xm+
# FSx4781FoADk+AR2u1fFkL53VJB0ngtPTcSqE4+XrwE1K8ubEXjp8vmJBDxO44IS
# Yuu0RAx1QcIPNLiIncgi8RNq2xgvbnitxAW06IQIkwf5fYP+aJg05Hflsc6MlGzb
# A20oBUd+my7wZPvbpAMxEHwa+zwZgNELcLlVX0e+OWTOt9ojVDLjRrIy2NIphskV
# XYCVrwL7tNEunTh8NeAPHO0bR0icImpVgtnyughlA+XxKfNIigkBTKZ58qK2GpmU
# 65co4b59G6F87VaApvQiM5DkhFP8KvrAp5eo6rWNes7k4EuhM6sLdqDVaRa3jma/
# X/ofxKh/p6FIFJENgvy9TZntyeZsNv53Q5m4aS18YS/to7BJ/lu+aSSR/5P8V2mS
# S9kFP22GctOi0MBk0jpCwRoD+9DtmiG4P6+mslFU1UzFyh8SjVfGOe1c/+yfJnat
# ZGZn6Kow4NKtt32xakEnbgOKo3TgigmCbr/j9re8ngspGGiBoZw/bhZZSxQJCZrm
# rr9gFd2G9TGCBlowggZWAgEBMGkwVDELMAkGA1UEBhMCR0IxGDAWBgNVBAoTD1Nl
# Y3RpZ28gTGltaXRlZDErMCkGA1UEAxMiU2VjdGlnbyBQdWJsaWMgQ29kZSBTaWdu
# aW5nIENBIFIzNgIRAPQbCCfcuboB1FpiBQ3KD8gwCQYFKw4DAhoFAKB4MBgGCisG
# AQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFItc
# kl/ruCTANm9ototUzejX9CtIMA0GCSqGSIb3DQEBAQUABIICAFIeN4ahnLeK6rPg
# pwEDlBzgYBu1/BWfQ0P54rN0RPla3k8gpqLlkS/+IA8SSVCjV2gOVgjiZuNwIV/a
# va+YfGTWPKPW38mrsMii/+9Nlhew052lv2hn9bS8UkeF/NEi7jCfWX93onyZ7toI
# e12j4c7YH9P4AWGmOXYtbTZaKCc9FF01QlnvM6pvzs6++sCg6ijXSD7arVAr415q
# 0tih0NqRFy6rsAiIewC+zxqCAzpCpiW8mIteY1EJpv1aVFnUMWoCOh6zV5zBKNS/
# Wg1jRjxVeqdvkEJT7Pc840LjGj23l9RrY4MKzLQaUPPFUBjxxh9jEm/rl3AxM3NG
# rKsAWVVNgsJeuf/NrBCMHhXJSFWaoD49jfzeS5J54ab3531kqY9u+uJXvEH2kMyn
# wrV6elQEvPunRXEYiHgAhVJVL1Zctysc0EcrrGRjgIhiNLeIAhpY/j6Xm45vh5hY
# l7KO88YQxL68PRx3tD5paL9YFISas/Qe3iq5c5PJyEGmDYVIcAcQbdVlqPgUlJ2u
# m87M10HoxA+hJ4y2C4WcK86LUJpDD1iO97sjQkhg1mvCOYEeKPGc1WWzIcnh2EZS
# /Sez/xbHuu7N6NhBfDfy8yVumCttLhRu7l6EPbj/NAyBbVad53UBqSw1262k0ENk
# mr8t3YPpQweoM99iomW/1OacjFigoYIDTDCCA0gGCSqGSIb3DQEJBjGCAzkwggM1
# AgEBMIGSMH0xCzAJBgNVBAYTAkdCMRswGQYDVQQIExJHcmVhdGVyIE1hbmNoZXN0
# ZXIxEDAOBgNVBAcTB1NhbGZvcmQxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEl
# MCMGA1UEAxMcU2VjdGlnbyBSU0EgVGltZSBTdGFtcGluZyBDQQIRAJA5f5rSSjoT
# 8r2RXwg4qUMwDQYJYIZIAWUDBAICBQCgeTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcN
# AQcBMBwGCSqGSIb3DQEJBTEPFw0yMzA0MjUyMTM4NDVaMD8GCSqGSIb3DQEJBDEy
# BDB5dFvgtTpJDxt6d5BWqZW5aehZHvICRh5ql1dVVJiWM2PU0lnhgs3ucwMUQRAC
# meAwDQYJKoZIhvcNAQEBBQAEggIAhymhfj+leq0asoHNeIJhYSSLaVz8C+Fx74YR
# 7MjOzF9iHkTxyx66J1GfeDp1BcjXG1Jr1mjO0H5glz8/Ggugq2kiBTbnai+NA3kV
# yuv/ugOpCGc25kexTrJDy9m0H+etMpSNofVAa0Cd9ExwvowLIuFOmo2/fnvxPrNG
# HyI0mmYsqSvYsbHBj31MGygqFkVGnzvAdzP3hyi4kHuPo9fuNuvMujagNzQ9EUhg
# QEkf6LfucJDimX8UnoXfn0A+qF5gSabn/F5xeBagB/I4J25KxBG/SPUEAwyJ1E0i
# 4HAcbT4ZeCIFTu1kUUd7gz48dPmzGtAwAQlWQMIwd/o+orvNq8BXaaRjS+Heklkk
# 7RLPSgltbuUu9KWnLRqhT3d+rqp+D123QHVCrokDGriPyZcdbOgPnV1cuylEyQX2
# UVJNVToLifLpDiFLLIPDkw8HtIkXNnBQ8cGO0mnDYIAE0FWRW9/Tuua/66dvRKSA
# uMuikNnxI7wvcUEjnlee3b2idtwhaTZ31Kzv59uL68Oesoxgqm/OaZKiD8jeUM/W
# 8klZe4lvQdWBYRUwf+mrM3/ho/LPHgU/Z+4vsciI283HXReC/ailivPBndSrrqCq
# hvwcnHuXxgDYzIX/+u6fbkQbbEOZaMlGbySNXr9NbopPYhFjqjoXvQPI5THHcJG2
# bjpsH9E=
# SIG # End signature block
