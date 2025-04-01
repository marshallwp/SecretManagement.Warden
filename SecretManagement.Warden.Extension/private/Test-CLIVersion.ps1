<#
.SYNOPSIS
    Checks Bitwarden CLI version against blacklist.
.DESCRIPTION
    Long description
.EXAMPLE
    An example
.NOTES
    General notes
#>
function Test-CLIVersion {
    [CmdletBinding()]
    Param(
        # CommandInfo of the Bitwarden CLI. Returned from Get-Command or dehydrated from Import-CliXml.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if($_.PSTypeNames -match '^(?:Deserialized\.)?System\.Management\.Automation\.CommandInfo$')
            { return $true }
            else { throw "Cannot convert the `"$_`" value of type `"$iptType`" to type `"System.Management.Automation.CommandInfo`"." }
        })]
        [PSObject]$BitwardenCLI,
        # Minimum Supported Version of the Bitwarden CLI.
        [ValidateNotNullOrEmpty()]
        [Version]$MinSupportedVersion = '2022.8.0'
    )

#region Get CLI Version
    # Get the Version number from file metadata if possible.
    [Version]$CurrentVersion = $BitwardenCLI.Version

    # ?Find the version elsewhere if the file version would fail the test. Workaround for how the file version is not always the cli version.
    if( $CurrentVersion -lt $MinSupportedVersion ) {
        # Handle the various shims
        # ?The Brew CLI is rather fast so we use it to get version number
        $HomebrewPrefix = $env:HOMEBREW_PREFIX ?? "/home/linuxbrew/.linuxbrew"
        if ( $BitwardenCLI.Source -eq "$HomebrewPrefix/bin/bw" -and (Get-Command brew -ErrorAction Ignore))
        {
            $CurrentVersion = ((brew list bitwarden-cli --versions) -split ' ')[1]
        }
        # ?The Chocolatey CLI is very slow, so we prefer querying bw directly if needed.
        # if ( $BitwardenCLI.Source -eq (Join-Path $env:ProgramData "chocolatey" "bin" "bw.exe") `
        #     -and (Get-Command choco -ErrorAction Ignore))
        # {
        #     $CurrentVersion = (choco info bitwarden-cli --local-only --limit-output).Split("|")[1]
        # }
        # ?npm creates a ps1 shim that is stripped of all version info. The CLI is fast though.
        elseif ( $BitwardenCLI.Name -eq "bw.ps1" -and (Get-Command npm -ErrorAction Ignore)) {
            $CurrentVersion = (npm view -g @bitwarden/cli version)
        }
        # ?Scoop shims eliminate version numbers, so we ask scoop for the true version.
        elseif( $BitwardenCLI.Source -like "*\scoop\shims\bw.exe" -and (Get-Command scoop -ErrorAction Ignore)) {
            $CurrentVersion = (scoop list bitwarden-cli 6> $null).Version ?? $CurrentVersion
        }
        # ?Getting the version from snap is very fast, so ask it for that.
        elseif( $BitwardenCLI.Source -like "*/snapd/snap/bin/bw" -and (Get-Command snap -ErrorAction Ignore) ) {
            # Query snap for a list containing only the bw command.
            $snapVerChk = snap list bw
            # Get the position of the Version Header and treat that as the startPos
            $startPos = ($snapVerChk | Select-String Version).Matches[0].Index
            # Get the position of the first space after startPos on line 2
            $endPos = $snapVerChk[1].Substring($startPos).IndexOf(' ')
            # The version is the text between the startPos and endPos on line 2.
            $CurrentVersion = $snapVerChk[1].Substring($startPos, $endPos) ?? $CurrentVersion
        }
        # ?WinGet shims have the wrong version, and the winget CLI is slow.  Disabled in favor of querying bw.exe instead.
        # elseif( $BitwardenCLI.Source -like "*\WinGet\Links\bw.exe" -or <# Machine Scope #>
        #         $BitwardenCLI.Source -like "*\Winget\Packages\*\bw.exe" <# User Scope #>) {
        #     $wingetVerChk = winget list --id Bitwarden.CLI
        #     $startPos = ($wingetVerChk | Select-String Version).Matches[0].Index
        #     $endPos = ($wingetVerChk | Where-Object {![String]::IsNullOrWhiteSpace($_) -and $_.Length -gt $startPos})[2].Substring($startPos).IndexOf(' ')
        #     $CurrentVersion = $snapVerChk[1].Substring($startPos, $endPos) ?? $CurrentVersion
        # }
        # ?If all other methods fail, ask bw.exe what version it is. This is a surprisingly slow process.
        else {
            $CurrentVersion = (.$BitwardenCLI --version) ?? $CurrentVersion
        }
    }
#endregion Get CLI Version


#region Version Warnings
    # Default Warning Message templates. Will be used if a localized variant cannot be found in the localization subdirectory.
    #culture="en-US"
    $Warnings = DATA {@{
        WarnOutdated        = "Your bitwarden-cli is version {0} and is out of date. Please upgrade to at least version {1}."
        WarnSpecificVersion = "Your bitwarden-cli is version {0}. This version of the CLI has a known issue affecting [{1}], which is used by [{2}]."
        WarnVersionRange    = "Your bitwarden-cli is version {0}. Versions {1} - {2} of the CLI have a known issue affecting [{3}], which is used by [{4}]."
        See                 = "See: {0}."
        StrongAction        = "It is `e[3mstrongly`e[23m recommended that you move to another version."
    }}
    Import-LocalizedData -BindingVariable Warnings -BaseDirectory (Join-Path $PSScriptRoot "localization") -ErrorAction Ignore

    if ( $CurrentVersion -lt $MinSupportedVersion ) {
        Write-Warning ($Warnings.WarnOutdated -f $CurrentVersion, $MinSupportedVersion)
    }
    elseif ( $CurrentVersion -ge '2023.12.0' -and $CurrentVersion -le '2023.12.1' ) {
        $warn = "{0} {1} {2}" -f ($Warnings.WarnVersionRange -f $CurrentVersion, '2023.12.0', '2023.12.1', 'bw list', 'Test-SecretVault'),
                                 ($Warnings.See -f 'https://github.com/bitwarden/clients/issues/7126'),
                                  $Warnings.StrongAction
        Write-Warning $warn
    }
    elseif ( $CurrentVersion -ge '2024.6.1' -and $CurrentVersion -le '2024.7.1' ) {
        $warn = "{0} {1} {2}" -f ($Warnings.WarnVersionRange -f $CurrentVersion, '2024.6.1', '2024.7.1', 'bw unlock', 'Unlock-SecretVault'),
                                 ($Warnings.See -f 'https://github.com/bitwarden/clients/issues/9919'),
                                  $Warnings.StrongAction
        Write-Warning $warn
    }
#endregion Version Warnings
}

# SIG # Begin signature block
# MIIsAAYJKoZIhvcNAQcCoIIr8TCCK+0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDQl9aTijLlFlE8
# cob42Ux8oiIfo0VyHuUaOI8A65s3YqCCJRUwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# Qem4LwrlLgcdO/YAnHqY52QwnBLiAuUnuBeshWmfEb5oieIYMIIGgTCCBOmgAwIB
# AgIRAPBLoOFxsqHd528YPxR6EZ0wDQYJKoZIhvcNAQEMBQAwVDELMAkGA1UEBhMC
# R0IxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDErMCkGA1UEAxMiU2VjdGlnbyBQ
# dWJsaWMgQ29kZSBTaWduaW5nIENBIFIzNjAeFw0yNTAzMjcwMDAwMDBaFw0yODAz
# MjYyMzU5NTlaMHExCzAJBgNVBAYTAlVTMQ4wDAYDVQQIDAVUZXhhczEoMCYGA1UE
# CgwfSW5kdXN0cmlhbCBJbmZvIFJlc291cmNlcywgSW5jLjEoMCYGA1UEAwwfSW5k
# dXN0cmlhbCBJbmZvIFJlc291cmNlcywgSW5jLjCCAiIwDQYJKoZIhvcNAQEBBQAD
# ggIPADCCAgoCggIBAJTo8VMmi4PENOZ0/uzyiZipTX2z+hDt6RnIDKkpv/safk+M
# 6pTsGeVzeXhiQC/DQvE1xTPfgz4v0ZDBQhkDj8EdgL+p0Ajy8B0jH6PlTlcenU/A
# Vt8rLEZ5DnoIDmMYFIZoAWp2k4lwcZXLP934p5QQoigIaaZL4u33h2KJHLYHi6DI
# jpdnDsptan7kXkeYD5izjnpv4LRfuVZsxrO5VyO1sAsnHwAvmEIEpxd0MD0ERTUk
# hCYy/0Lb5CASxvwM58ysEL2aUt+oGiVDwhKn2SX0goyaiZE4tEGJIa0Lg6V4MoES
# x572rvLrsmQISLoRos5Rw/opcp3gcrZ2DRUuGT5Q8M0EnwemocFBXfSY6de+/ifR
# sU7spY8ZIDlNIX+Ldw8KRGZk/aV0Bkf0iTF8fnG5fpjxgFbLGnbnGuexyLX5LKBG
# 0kDa8qW9At5Vone/xPXYg6UYIk0FM0+F8mrjrjKIhQYXXQ//l8AukItQq1oXsbhM
# aORIl2GkeKjXZJph4qW6ZnJz1QFMTBenAaT76z9Lg+JgZyMRlHyBoevX4srWNZlN
# ZyYA8DpsQFDOT5UeU7sSHKqFRq6Dz5WHailf4rcxHX4edOoGWd8NrlHJ59PraVpi
# ZP/MyJDCQcfja0PKwr+AOWI/Tccbo6tlqO9l183DL3+H6kA24+Ccl/5gczWPAgMB
# AAGjggGvMIIBqzAfBgNVHSMEGDAWgBQPKssghyi47G9IritUpimqF6TNDDAdBgNV
# HQ4EFgQUQRsTedOwE3arDa2qSQdUKSXRSegwDgYDVR0PAQH/BAQDAgeAMAwGA1Ud
# EwEB/wQCMAAwEwYDVR0lBAwwCgYIKwYBBQUHAwMwSgYDVR0gBEMwQTA1BgwrBgEE
# AbIxAQIBAwIwJTAjBggrBgEFBQcCARYXaHR0cHM6Ly9zZWN0aWdvLmNvbS9DUFMw
# CAYGZ4EMAQQBMEkGA1UdHwRCMEAwPqA8oDqGOGh0dHA6Ly9jcmwuc2VjdGlnby5j
# b20vU2VjdGlnb1B1YmxpY0NvZGVTaWduaW5nQ0FSMzYuY3JsMHkGCCsGAQUFBwEB
# BG0wazBEBggrBgEFBQcwAoY4aHR0cDovL2NydC5zZWN0aWdvLmNvbS9TZWN0aWdv
# UHVibGljQ29kZVNpZ25pbmdDQVIzNi5jcnQwIwYIKwYBBQUHMAGGF2h0dHA6Ly9v
# Y3NwLnNlY3RpZ28uY29tMCQGA1UdEQQdMBuBGWRqb2hsZUBpbmR1c3RyaWFsaW5m
# by5jb20wDQYJKoZIhvcNAQEMBQADggGBAJGlnYS12frEvVEm7oPB4HZOEslmW8UQ
# FaJt8985Vbrs1lf7rLdhVJ8MMDqsHY90vlO0zKRwoRzgJaA1TL1DaAl4gbNXPFMR
# TXJBuXt51zoGvL2WbqJ879RND6qheuLxZGrFaFqD33JfKuWmJmNf3mFs5IZ5CZGB
# tolClIBZ/EKbkZgp5IwLihLNYlawendjTZHGRsu7v7SI+WEzZg5mDeHck3KFqCMq
# iJw97uJ+YnIFktYD5UNAOfT0RkkZ/qdEGKkhB1MDfMekz+KuRykyJGAq8YCp6wqf
# YjGPB0VWzgAVJWpOFIvX9KtZnc/80vG0nZjZg1sX6S9WuThXm5GMiLjzLLbKB4nY
# eiwuOEkk4YbXzvWZzYC+jVk0IExRVZV+rfpS9wW3R3qGoKoah9OJ8k9IyW4a66V3
# 1GgDmOVCKEnyP0CduxbqGwe4TmowJNewz2E7nDFMV+XZUFcq77bIl0N6624DCvWE
# C1iQNenkQ0z1PjRXeZ/lEfjxNmJYViymdjCCBoIwggRqoAMCAQICEDbCsL18Gzrn
# o7PdNsvJdWgwDQYJKoZIhvcNAQEMBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpOZXcgSmVyc2V5MRQwEgYDVQQHEwtKZXJzZXkgQ2l0eTEeMBwGA1UEChMVVGhl
# IFVTRVJUUlVTVCBOZXR3b3JrMS4wLAYDVQQDEyVVU0VSVHJ1c3QgUlNBIENlcnRp
# ZmljYXRpb24gQXV0aG9yaXR5MB4XDTIxMDMyMjAwMDAwMFoXDTM4MDExODIzNTk1
# OVowVzELMAkGA1UEBhMCR0IxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEuMCwG
# A1UEAxMlU2VjdGlnbyBQdWJsaWMgVGltZSBTdGFtcGluZyBSb290IFI0NjCCAiIw
# DQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAIid2LlFZ50d3ei5JoGaVFTAfEkF
# m8xaFQ/ZlBBEtEFAgXcUmanU5HYsyAhTXiDQkiUvpVdYqZ1uYoZEMgtHES1l1Cc6
# HaqZzEbOOp6YiTx63ywTon434aXVydmhx7Dx4IBrAou7hNGsKioIBPy5GMN7KmgY
# muu4f92sKKjbxqohUSfjk1mJlAjthgF7Hjx4vvyVDQGsd5KarLW5d73E3ThobSko
# b2SL48LpUR/O627pDchxll+bTSv1gASn/hp6IuHJorEu6EopoB1CNFp/+HpTXeNA
# RXUmdRMKbnXWflq+/g36NJXB35ZvxQw6zid61qmrlD/IbKJA6COw/8lFSPQwBP1i
# tyZdwuCysCKZ9ZjczMqbUcLFyq6KdOpuzVDR3ZUwxDKL1wCAxgL2Mpz7eZbrb/JW
# XiOcNzDpQsmwGQ6Stw8tTCqPumhLRPb7YkzM8/6NnWH3T9ClmcGSF22LEyJYNWCH
# rQqYubNeKolzqUbCqhSqmr/UdUeb49zYHr7ALL8bAJyPDmubNqMtuaobKASBqP84
# uhqcRY/pjnYd+V5/dcu9ieERjiRKKsxCG1t6tG9oj7liwPddXEcYGOUiWLm742st
# 50jGwTzxbMpepmOP1mLnJskvZaN5e45NuzAHteORlsSuDt5t4BBRCJL+5EZnnw0e
# zntk9R8QJyAkL6/bAgMBAAGjggEWMIIBEjAfBgNVHSMEGDAWgBRTeb9aqitKz1SA
# 4dibwJ3ysgNmyzAdBgNVHQ4EFgQU9ndq3T/9ARP/FqFsggIv0Ao9FCUwDgYDVR0P
# AQH/BAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wEwYDVR0lBAwwCgYIKwYBBQUHAwgw
# EQYDVR0gBAowCDAGBgRVHSAAMFAGA1UdHwRJMEcwRaBDoEGGP2h0dHA6Ly9jcmwu
# dXNlcnRydXN0LmNvbS9VU0VSVHJ1c3RSU0FDZXJ0aWZpY2F0aW9uQXV0aG9yaXR5
# LmNybDA1BggrBgEFBQcBAQQpMCcwJQYIKwYBBQUHMAGGGWh0dHA6Ly9vY3NwLnVz
# ZXJ0cnVzdC5jb20wDQYJKoZIhvcNAQEMBQADggIBAA6+ZUHtaES45aHF1BGH5Lc7
# JYzrftrIF5Ht2PFDxKKFOct/awAEWgHQMVHol9ZLSyd/pYMbaC0IZ+XBW9xhdkkm
# UV/KbUOiL7g98M/yzRyqUOZ1/IY7Ay0YbMniIibJrPcgFp73WDnRDKtVutShPSZQ
# ZAdtFwXnuiWl8eFARK3PmLqEm9UsVX+55DbVIz33Mbhba0HUTEYv3yJ1fwKGxPBs
# P/MgTECimh7eXomvMm0/GPxX2uhwCcs/YLxDnBdVVlxvDjHjO1cuwbOpkiJGHmLX
# XVNbsdXUC2xBrq9fLrfe8IBsA4hopwsCj8hTuwKXJlSTrZcPRVSccP5i9U28gZ7O
# MzoJGlxZ5384OKm0r568Mo9TYrqzKeKZgFo0fj2/0iHbj55hc20jfxvK3mQi+H7x
# pbzxZOFGm/yVQkpo+ffv5gdhp+hv1GDsvJOtJinJmgGbBFZIThbqI+MHvAmMmkfb
# 3fTxmSkop2mSJL1Y2x/955S29Gu0gSJIkc3z30vU/iXrMpWx2tS7UVfVP+5tKuzG
# tgkP7d/doqDrLF1u6Ci3TpjAZdeLLlRQZm867eVeXED58LXd1Dk6UvaAhvmWYXoi
# Lz4JA5gPBcz7J311uahxCweNxE+xxxR3kT0WKzASo5G/PyDez6NHdIUKBeE3jDPs
# 2ACc6CkJ1Sji4PKWVT0/MYIGQTCCBj0CAQEwaTBUMQswCQYDVQQGEwJHQjEYMBYG
# A1UEChMPU2VjdGlnbyBMaW1pdGVkMSswKQYDVQQDEyJTZWN0aWdvIFB1YmxpYyBD
# b2RlIFNpZ25pbmcgQ0EgUjM2AhEA8Eug4XGyod3nbxg/FHoRnTANBglghkgBZQME
# AgEFAKCBhDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqG
# SIb3DQEJBDEiBCBi44wy7il25YLbaZaJ9PV4LAN8rhEwd7Mq+Q5uJSxTJjANBgkq
# hkiG9w0BAQEFAASCAgBHim3UrurPXEC62+OtYGIGdnDfw/M3hb1sGntKTEv1OQZh
# JGUZNWxyzOut0xdfIAwgGs6qdaWKF8ykeO0f/WGQqHHROEZOyqyx6Qvjm5ULa24T
# oLjhg6glrTXOQpRqAf7mQW+7VtfVtYAYl6Yux9Fl5BRVAyMWStj3zemnb5lK3w4O
# XDX5QpOe8VjyZel41HeCZ4JnVB6z1eO3a706RkxFaHeyKArI8VJlQw2evJkItcC9
# PJa/yVDOPgYRQRzYtq6UDDg1xW1u0iV9f8DiFsjMw5gTPc9tJxP3GJQQCSjm9stz
# l5v55ClEs8WVfywww1WF+z6CRhMB9u57MMnyUK3COQ01eOqCxwuMztGEvoznFBYk
# 869JjT1bF7f6gnWlxiLjizpNbvv8R1+S4Beda13WpsXrIfF9HJxDhaf+ufUVLlsp
# mrl6x3pQOxQ89bdEJWNPLAqId/aM8YwhhPD2Kw/fkl0jkBkxbzFkxIbJHV01s8DL
# T3Kj1bZLVmXOqq0rTASTDkZwUD2V+OttPPf1qjqIocD7EvuERYANcOB1L0WR6uZs
# 8K0rHNYJhojEoFdVMCEPB9z/0BRS/f8MmDeGEjGEFnHubm3Li8glwZJIP//228La
# 2JOfkGxSP3FPxOByFjYrPv0YNCabN3zSUoPqh//uEbySdBo+H1afCTh531Lmv6GC
# AyIwggMeBgkqhkiG9w0BCQYxggMPMIIDCwIBATBpMFUxCzAJBgNVBAYTAkdCMRgw
# FgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLDAqBgNVBAMTI1NlY3RpZ28gUHVibGlj
# IFRpbWUgU3RhbXBpbmcgQ0EgUjM2AhA6UmoshM5V5h1l/MwS2OmJMA0GCWCGSAFl
# AwQCAgUAoHkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUx
# DxcNMjUwNDAxMjAzMjA5WjA/BgkqhkiG9w0BCQQxMgQwBLQ2xgrPTPnJ3uyZHpaJ
# qWeM04ZsFfQRbTuU8C6k1Pknh8bEfPNgvzcJIXvyxef+MA0GCSqGSIb3DQEBAQUA
# BIICAAVAYXWmUIGRKANffv7F0o37FVUNq10k8OhEj/czMu8/Otnd0StW+MhIP/CX
# lHjyTTy9fjADigqf0noT3tcsx9bazk/Q5eDh2IT2+y6nb03DzQ8w7QMcWLeIIe62
# a4kkrWld4R9HIWXbRPiUULWHMkMg704OjJV8dBCln26/LrTlk6fp3Bz0PvHB5voA
# pvm3DwC5v8Eby/S2bP0XChfEoMrR+anVxKR/3zqp8VBhNwIFsZAHwlZUs1sldchC
# hvWv1gFA+bnCaMivWN/bmDWf1nZj/9SPNeZ6XWovhqs9P1wXRTn/FZ7J3uWeUnRX
# MmtaNoPxJ54I+ue8q/ikTS/9/RUIV8bI5Q7h9rZMreJUwWHwftK38cpAax4svNhY
# BGo05UKQfY9zjvlCPUKPyqu9phJqsVhhQwq9noZ+ErbvGIBxjPPazip9+GZPo1d2
# NuROJg3TGygX65pr8iemjtLJIdIwFRbiAUqCOp/bBde64fxY6X9Ee82FafLRLdYm
# FHtd6byU9I7z9eKnOEMbWqG5qor9WRdlXrIYgZDYJcpm5KP8+1nNeHi7eohxPA5X
# yu8kqtK42boovSzLUZhyn9Ex8+lkDYJVbrBbw3xTen5i94iB1/tDA1ky+aJnty1/
# 6dVlBnBJhrfo8M/LzvdbNOW7YopWzJw5IbFud2tx0DKdAOJC
# SIG # End signature block
