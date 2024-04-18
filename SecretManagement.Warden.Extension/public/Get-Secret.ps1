<#
.SYNOPSIS
    Retrieves a single secret from the vault or null if no secret is found.
.DESCRIPTION
    Retrives a single secret from the vault.  Corresponds with the "bw get" functionality of the CLI.
.NOTES
    Per SecretManagement documentation, "The Get-Secret cmdlet writes the retrieved secret value to the output pipeline on return, or null if no secret was found. It should write an error only if an abnormal condition occurs."
#>
function Get-Secret {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "VaultName", Justification = "Function must accept this parameter to be valid.")]
    param(
        [Parameter(ValueFromPipelineByPropertyName, Mandatory=$true)]
        [Alias('ID')][string] $Name,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $VaultName,
        [Parameter(ValueFromPipelineByPropertyName)]
        [hashtable] $AdditionalParameters
    )
    # Enable Verbose Mode inside this script if passed from the wrapper.
    if($AdditionalParameters.ContainsKey('Verbose') -and ($AdditionalParameters['Verbose'] -eq $true)) {$script:VerbosePreference = 'Continue'}
    $AdditionalParameters = Merge-Defaults $AdditionalParameters
    Sync-BitwardenVault $AdditionalParameters.ResyncCacheIfOlderThan

    [System.Collections.Generic.List[string]]$CmdParams = @("get","item")
    $CmdParams.Add( $Name ) #* Do not combine with the above line.  For some reason that causes the function to fail in production.

    if ( $AdditionalParameters.ContainsKey('organizationid') ) {
        $CmdParams.Add( '--organizationid' )
        $CmdParams.Add( $AdditionalParameters['organizationid'] )
    }

    try {
        $Result = Invoke-BitwardenCLI @CmdParams
    }
    # Per SecretManagement Readme, if a secret is not found, Get-Secret should return null, not an error.
    catch [System.Management.Automation.ItemNotFoundException],[System.DirectoryServices.AccountManagement.NoMatchingPrincipalException] {
        return $null
    }

    switch ( $Result.type ) {
        "SecureNote" {
            $ObjType = ($Result.notes | Select-String -Pattern "(?<=PowerShellObjectRepresentation: )[^\n]*").Matches | Select-Object -First 1 -ExpandProperty Groups | Select-Object -First 1 -ExpandProperty Values
            if( !$ObjType ) {
                return $Result.notes
            }
            elseif( $ObjType -ieq "CliXml" ) {
                $tmp = New-TemporaryFile
                $Result.notes.Remove(0,$Result.notes.IndexOf("`n")+1) | Out-File -FilePath $tmp
                $obj = Import-Clixml -Path $tmp
                Remove-Item $tmp -Force
                return $obj
            }
            elseif( $ObjType -ieq "JSON" ) {
                $note = $Result.notes.Remove(0,$Result.notes.IndexOf("`n")+1)
                return $note | ConvertFrom-Json -AsHashtable
            }
            else {
                $ex = New-Object System.NotSupportedException "$ObjType is not a supported means of representing a PowerShell Object. Only CliXml and JSON representations are supported."
                Write-Error -Exception $ex -Category NotImplemented -ErrorId "InvalidObjectRepresentation" -ErrorAction Stop
            }

            break
        }
        { "Login","Card","Identity" -icontains $_ } {
            # Output login as a hashtable. This allows us to support credentials that lack a username and therefore cannot output a PSCredential.
            #* Unlike Get-SecretInfo, Get-Secret does not support ordered hashtables.
            return $Result.$_ | ConvertTo-Hashtable
            break
        }
        default {throw [System.NotImplementedException]"Somehow you got to a place that doesn't exist."; break}
    }
}

# SIG # Begin signature block
# MIInJAYJKoZIhvcNAQcCoIInFTCCJxECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAXrUDU/ihPSirc
# BKi8BmZ5zApwajMvpmKIqdlGVjuhY6CCIBAwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# +9/DUp/mBlXpnYzyOmJRvOwkDynUWICE5EV7WtgwggYaMIIEAqADAgECAhBiHW0M
# UgGeO5B5FSCJIRwKMA0GCSqGSIb3DQEBDAUAMFYxCzAJBgNVBAYTAkdCMRgwFgYD
# VQQKEw9TZWN0aWdvIExpbWl0ZWQxLTArBgNVBAMTJFNlY3RpZ28gUHVibGljIENv
# ZGUgU2lnbmluZyBSb290IFI0NjAeFw0yMTAzMjIwMDAwMDBaFw0zNjAzMjEyMzU5
# NTlaMFQxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxKzAp
# BgNVBAMTIlNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBDQSBSMzYwggGiMA0G
# CSqGSIb3DQEBAQUAA4IBjwAwggGKAoIBgQCbK51T+jU/jmAGQ2rAz/V/9shTUxjI
# ztNsfvxYB5UXeWUzCxEeAEZGbEN4QMgCsJLZUKhWThj/yPqy0iSZhXkZ6Pg2A2NV
# DgFigOMYzB2OKhdqfWGVoYW3haT29PSTahYkwmMv0b/83nbeECbiMXhSOtbam+/3
# 6F09fy1tsB8je/RV0mIk8XL/tfCK6cPuYHE215wzrK0h1SWHTxPbPuYkRdkP05Zw
# mRmTnAO5/arnY83jeNzhP06ShdnRqtZlV59+8yv+KIhE5ILMqgOZYAENHNX9SJDm
# +qxp4VqpB3MV/h53yl41aHU5pledi9lCBbH9JeIkNFICiVHNkRmq4TpxtwfvjsUe
# dyz8rNyfQJy/aOs5b4s+ac7IH60B+Ja7TVM+EKv1WuTGwcLmoU3FpOFMbmPj8pz4
# 4MPZ1f9+YEQIQty/NQd/2yGgW+ufflcZ/ZE9o1M7a5Jnqf2i2/uMSWymR8r2oQBM
# dlyh2n5HirY4jKnFH/9gRvd+QOfdRrJZb1sCAwEAAaOCAWQwggFgMB8GA1UdIwQY
# MBaAFDLrkpr/NZZILyhAQnAgNpFcF4XmMB0GA1UdDgQWBBQPKssghyi47G9IritU
# pimqF6TNDDAOBgNVHQ8BAf8EBAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIBADATBgNV
# HSUEDDAKBggrBgEFBQcDAzAbBgNVHSAEFDASMAYGBFUdIAAwCAYGZ4EMAQQBMEsG
# A1UdHwREMEIwQKA+oDyGOmh0dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1B1
# YmxpY0NvZGVTaWduaW5nUm9vdFI0Ni5jcmwwewYIKwYBBQUHAQEEbzBtMEYGCCsG
# AQUFBzAChjpodHRwOi8vY3J0LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNDb2Rl
# U2lnbmluZ1Jvb3RSNDYucDdjMCMGCCsGAQUFBzABhhdodHRwOi8vb2NzcC5zZWN0
# aWdvLmNvbTANBgkqhkiG9w0BAQwFAAOCAgEABv+C4XdjNm57oRUgmxP/BP6YdURh
# w1aVcdGRP4Wh60BAscjW4HL9hcpkOTz5jUug2oeunbYAowbFC2AKK+cMcXIBD0Zd
# OaWTsyNyBBsMLHqafvIhrCymlaS98+QpoBCyKppP0OcxYEdU0hpsaqBBIZOtBajj
# cw5+w/KeFvPYfLF/ldYpmlG+vd0xqlqd099iChnyIMvY5HexjO2AmtsbpVn0OhNc
# WbWDRF/3sBp6fWXhz7DcML4iTAWS+MVXeNLj1lJziVKEoroGs9Mlizg0bUMbOalO
# hOfCipnx8CaLZeVme5yELg09Jlo8BMe80jO37PU8ejfkP9/uPak7VLwELKxAMcJs
# zkyeiaerlphwoKx1uHRzNyE6bxuSKcutisqmKL5OTunAvtONEoteSiabkPVSZ2z7
# 6mKnzAfZxCl/3dq3dUNw4rg3sTCggkHSRqTqlLMS7gjrhTqBmzu1L90Y1KWN/Y5J
# KdGvspbOrTfOXyXvmPL6E52z1NZJ6ctuMFBQZH3pwWvqURR8AgQdULUvrxjUYbHH
# j95Ejza63zdrEcxWLDX6xWls/GDnVNueKjWUH3fTv1Y8Wdho698YADR7TNx8X8z2
# Bev6SivBBOHY+uqiirZtg0y9ShQoPzmCcn63Syatatvx157YK9hlcPmVoa1oDE5/
# L9Uo2bC5a4CH2RwwggaSMIIE+qADAgECAhEA9BsIJ9y5ugHUWmIFDcoPyDANBgkq
# hkiG9w0BAQwFADBUMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1p
# dGVkMSswKQYDVQQDEyJTZWN0aWdvIFB1YmxpYyBDb2RlIFNpZ25pbmcgQ0EgUjM2
# MB4XDTIyMDMyMzAwMDAwMFoXDTI1MDMyMjIzNTk1OVowfjELMAkGA1UEBhMCVVMx
# DjAMBgNVBAgMBVRleGFzMSgwJgYDVQQKDB9JbmR1c3RyaWFsIEluZm8gUmVzb3Vy
# Y2VzLCBJbmMuMQswCQYDVQQLDAJJVDEoMCYGA1UEAwwfSW5kdXN0cmlhbCBJbmZv
# IFJlc291cmNlcywgSW5jLjCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIB
# AJ7E7i62hCOgQLnF+wZZo8Rfl4dLolApxc+xD6cbXmk767hIZ/c7P+QCmLsZGqaZ
# BKT+pBz2HKchvi3I1BqANkPa9arn2MYTRQZ1I57IJmZb/TwgybUxKtiyZxjYjw74
# iRmcReCa52Zyv7TethAR/v5ygApM8HzCgWoqa9/IWGcRSpHKWHHcINmLO/DO/8BX
# D93T9fCfRdY4L69H2QbQkNh0lye1QTp/70VDu1o83sdWeGrXJhCZvpZlEeEgUUEG
# 2M5zwJr4Ro2ZEVATCAp3BPt/2rjniGh2Zos7yD2+1WmrOgTBYVw/K+Yk265zjhF0
# asr7Ek4frWaccPjiBYWCxDDvLKn7hMfQP8FTD+qzMAsWls2Zn05R1gHrttlZ8gbY
# aQXNaOYFhKat6w25emvD9sJPFFJVZCvnp9Pz+fKQhEhqffWeMZBLFdlQoLIvDkhJ
# Ws9+jbnowitu0KKlk0dkiQVLYUIQpiPRhPGaJKscyHzAQ87DD3Ox/6S/TGhNJFMM
# 3hFuvRnaZ2P12cVvHmD8OqVSwDhQsl01Fg8VioGrd0BxgNP5bWiTz+eMRChf0o3J
# Vpj9Ortz6sdTwAJgE8Dd8Im+5sRRWfBHROS3sCR5pgYEJdmNMARcbA7tecdKK20e
# P+AkyH4t8Hevx3hMKhS4nZArU/kCE4nGhAv0n4/riHWnAgMBAAGjggGzMIIBrzAf
# BgNVHSMEGDAWgBQPKssghyi47G9IritUpimqF6TNDDAdBgNVHQ4EFgQUfukDRLuk
# n0rpdU1Lx5oydHrJyCowDgYDVR0PAQH/BAQDAgeAMAwGA1UdEwEB/wQCMAAwEwYD
# VR0lBAwwCgYIKwYBBQUHAwMwSgYDVR0gBEMwQTA1BgwrBgEEAbIxAQIBAwIwJTAj
# BggrBgEFBQcCARYXaHR0cHM6Ly9zZWN0aWdvLmNvbS9DUFMwCAYGZ4EMAQQBMEkG
# A1UdHwRCMEAwPqA8oDqGOGh0dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1B1
# YmxpY0NvZGVTaWduaW5nQ0FSMzYuY3JsMHkGCCsGAQUFBwEBBG0wazBEBggrBgEF
# BQcwAoY4aHR0cDovL2NydC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljQ29kZVNp
# Z25pbmdDQVIzNi5jcnQwIwYIKwYBBQUHMAGGF2h0dHA6Ly9vY3NwLnNlY3RpZ28u
# Y29tMCgGA1UdEQQhMB+BHWhvc3RtYXN0ZXJAaW5kdXN0cmlhbGluZm8uY29tMA0G
# CSqGSIb3DQEBDAUAA4IBgQBXt+ecda0VKyotd+pMQHR1r84lxw40P6/NADb14P48
# p0iQYoFXBNmyq3kGtv4VFYVSDiiu/823nxt7Zm/0JtBN2WcLmt61ZELp23N+MxMA
# MSvriQ+PGMSXdix8w3aY3AJACUM0+gmynqTVpwhsZBkhxMlX0OpeFNv6VfoAvLo5
# rNZ5wD0KwlFTEid1WiOQImHHOC7kkQIuj6POkrby9ukDwbDIwRDgwpZEik2K5JtD
# /+kKBIK1Zrs6g8nnVPS+vjv494vDZBR6XCrct4HrAJfdU+Ch7/cTlo4DG4MePpEw
# MUml/GIQsU8uOqkf932TW6wm1oF6PGh0mysMVZ9ee+CBiL3WwZ6uV2yyZ2+k2+wQ
# r4HaM24OPp6r1ubGrAwclydFLBzI6cbxcRzakcPJ6EluQ3FdZyyB2S/S9yWTi//M
# IFsFbmywhhr0MrH6bwU4zPzuYOFVTvr6Ek/Cu8ZsEFneZ/7T8KEgoDSmL3XESd6K
# YLWkzMgPWqmGZTHmzZbaXzIwggbsMIIE1KADAgECAhAwD2+s3WaYdHypRjaneC25
# MA0GCSqGSIb3DQEBDAUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKTmV3IEpl
# cnNleTEUMBIGA1UEBxMLSmVyc2V5IENpdHkxHjAcBgNVBAoTFVRoZSBVU0VSVFJV
# U1QgTmV0d29yazEuMCwGA1UEAxMlVVNFUlRydXN0IFJTQSBDZXJ0aWZpY2F0aW9u
# IEF1dGhvcml0eTAeFw0xOTA1MDIwMDAwMDBaFw0zODAxMTgyMzU5NTlaMH0xCzAJ
# BgNVBAYTAkdCMRswGQYDVQQIExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcT
# B1NhbGZvcmQxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDElMCMGA1UEAxMcU2Vj
# dGlnbyBSU0EgVGltZSBTdGFtcGluZyBDQTCCAiIwDQYJKoZIhvcNAQEBBQADggIP
# ADCCAgoCggIBAMgbAa/ZLH6ImX0BmD8gkL2cgCFUk7nPoD5T77NawHbWGgSlzkeD
# tevEzEk0y/NFZbn5p2QWJgn71TJSeS7JY8ITm7aGPwEFkmZvIavVcRB5h/RGKs3E
# Wsnb111JTXJWD9zJ41OYOioe/M5YSdO/8zm7uaQjQqzQFcN/nqJc1zjxFrJw06PE
# 37PFcqwuCnf8DZRSt/wflXMkPQEovA8NT7ORAY5unSd1VdEXOzQhe5cBlK9/gM/R
# EQpXhMl/VuC9RpyCvpSdv7QgsGB+uE31DT/b0OqFjIpWcdEtlEzIjDzTFKKcvSb/
# 01Mgx2Bpm1gKVPQF5/0xrPnIhRfHuCkZpCkvRuPd25Ffnz82Pg4wZytGtzWvlr7a
# TGDMqLufDRTUGMQwmHSCIc9iVrUhcxIe/arKCFiHd6QV6xlV/9A5VC0m7kUaOm/N
# 14Tw1/AoxU9kgwLU++Le8bwCKPRt2ieKBtKWh97oaw7wW33pdmmTIBxKlyx3GSuT
# lZicl57rjsF4VsZEJd8GEpoGLZ8DXv2DolNnyrH6jaFkyYiSWcuoRsDJ8qb/fVfb
# Enb6ikEk1Bv8cqUUotStQxykSYtBORQDHin6G6UirqXDTYLQjdprt9v3GEBXc/Bx
# o/tKfUU2wfeNgvq5yQ1TgH36tjlYMu9vGFCJ10+dM70atZ2h3pVBeqeDAgMBAAGj
# ggFaMIIBVjAfBgNVHSMEGDAWgBRTeb9aqitKz1SA4dibwJ3ysgNmyzAdBgNVHQ4E
# FgQUGqH4YRkgD8NBd0UojtE1XwYSBFUwDgYDVR0PAQH/BAQDAgGGMBIGA1UdEwEB
# /wQIMAYBAf8CAQAwEwYDVR0lBAwwCgYIKwYBBQUHAwgwEQYDVR0gBAowCDAGBgRV
# HSAAMFAGA1UdHwRJMEcwRaBDoEGGP2h0dHA6Ly9jcmwudXNlcnRydXN0LmNvbS9V
# U0VSVHJ1c3RSU0FDZXJ0aWZpY2F0aW9uQXV0aG9yaXR5LmNybDB2BggrBgEFBQcB
# AQRqMGgwPwYIKwYBBQUHMAKGM2h0dHA6Ly9jcnQudXNlcnRydXN0LmNvbS9VU0VS
# VHJ1c3RSU0FBZGRUcnVzdENBLmNydDAlBggrBgEFBQcwAYYZaHR0cDovL29jc3Au
# dXNlcnRydXN0LmNvbTANBgkqhkiG9w0BAQwFAAOCAgEAbVSBpTNdFuG1U4GRdd8D
# ejILLSWEEbKw2yp9KgX1vDsn9FqguUlZkClsYcu1UNviffmfAO9Aw63T4uRW+VhB
# z/FC5RB9/7B0H4/GXAn5M17qoBwmWFzztBEP1dXD4rzVWHi/SHbhRGdtj7BDEA+N
# 5Pk4Yr8TAcWFo0zFzLJTMJWk1vSWVgi4zVx/AZa+clJqO0I3fBZ4OZOTlJux3LJt
# QW1nzclvkD1/RXLBGyPWwlWEZuSzxWYG9vPWS16toytCiiGS/qhvWiVwYoFzY16g
# u9jc10rTPa+DBjgSHSSHLeT8AtY+dwS8BDa153fLnC6NIxi5o8JHHfBd1qFzVwVo
# mqfJN2Udvuq82EKDQwWli6YJ/9GhlKZOqj0J9QVst9JkWtgqIsJLnfE5XkzeSD2b
# NJaaCV+O/fexUpHOP4n2HKG1qXUfcb9bQ11lPVCBbqvw0NP8srMftpmWJvQ8eYtc
# ZMzN7iea5aDADHKHwW5NWtMe6vBE5jJvHOsXTpTDeGUgOw9Bqh/poUGd/rG4oGUq
# NODeqPk85sEwu8CgYyz8XBYAqNDEf+oRnR4GxqZtMl20OAkrSQeq/eww2vGnL8+3
# /frQo4TZJ577AWZ3uVYQ4SBuxq6x+ba6yDVdM3aO8XwgDCp3rrWiAoa6Ke60WgCx
# jKvj+QrJVF3UuWp0nr1Irpgwggb1MIIE3aADAgECAhA5TCXhfKBtJ6hl4jvZHSLU
# MA0GCSqGSIb3DQEBDAUAMH0xCzAJBgNVBAYTAkdCMRswGQYDVQQIExJHcmVhdGVy
# IE1hbmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZvcmQxGDAWBgNVBAoTD1NlY3RpZ28g
# TGltaXRlZDElMCMGA1UEAxMcU2VjdGlnbyBSU0EgVGltZSBTdGFtcGluZyBDQTAe
# Fw0yMzA1MDMwMDAwMDBaFw0zNDA4MDIyMzU5NTlaMGoxCzAJBgNVBAYTAkdCMRMw
# EQYDVQQIEwpNYW5jaGVzdGVyMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLDAq
# BgNVBAMMI1NlY3RpZ28gUlNBIFRpbWUgU3RhbXBpbmcgU2lnbmVyICM0MIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEApJMoUkvPJ4d2pCkcmTjA5w7U0Rzs
# aMsBZOSKzXewcWWCvJ/8i7u7lZj7JRGOWogJZhEUWLK6Ilvm9jLxXS3AeqIO4OBW
# ZO2h5YEgciBkQWzHwwj6831d7yGawn7XLMO6EZge/NMgCEKzX79/iFgyqzCz2Ix6
# lkoZE1ys/Oer6RwWLrCwOJVKz4VQq2cDJaG7OOkPb6lampEoEzW5H/M94STIa7GZ
# 6A3vu03lPYxUA5HQ/C3PVTM4egkcB9Ei4GOGp7790oNzEhSbmkwJRr00vOFLUHty
# 4Fv9GbsfPGoZe267LUQqvjxMzKyKBJPGV4agczYrgZf6G5t+iIfYUnmJ/m53N9e7
# UJ/6GCVPE/JefKmxIFopq6NCh3fg9EwCSN1YpVOmo6DtGZZlFSnF7TMwJeaWg4Ga
# 9mBmkFgHgM1Cdaz7tJHQxd0BQGq2qBDu9o16t551r9OlSxihDJ9XsF4lR5F0zXUS
# 0Zxv5F4Nm+x1Ju7+0/WSL1KF6NpEUSqizADKh2ZDoxsA76K1lp1irScL8htKycOU
# QjeIIISoh67DuiNye/hU7/hrJ7CF9adDhdgrOXTbWncC0aT69c2cPcwfrlHQe2zY
# HS0RQlNxdMLlNaotUhLZJc/w09CRQxLXMn2YbON3Qcj/HyRU726txj5Ve/Fchzpk
# 8WBLBU/vuS/sCRMCAwEAAaOCAYIwggF+MB8GA1UdIwQYMBaAFBqh+GEZIA/DQXdF
# KI7RNV8GEgRVMB0GA1UdDgQWBBQDDzHIkSqTvWPz0V1NpDQP0pUBGDAOBgNVHQ8B
# Af8EBAMCBsAwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDBK
# BgNVHSAEQzBBMDUGDCsGAQQBsjEBAgEDCDAlMCMGCCsGAQUFBwIBFhdodHRwczov
# L3NlY3RpZ28uY29tL0NQUzAIBgZngQwBBAIwRAYDVR0fBD0wOzA5oDegNYYzaHR0
# cDovL2NybC5zZWN0aWdvLmNvbS9TZWN0aWdvUlNBVGltZVN0YW1waW5nQ0EuY3Js
# MHQGCCsGAQUFBwEBBGgwZjA/BggrBgEFBQcwAoYzaHR0cDovL2NydC5zZWN0aWdv
# LmNvbS9TZWN0aWdvUlNBVGltZVN0YW1waW5nQ0EuY3J0MCMGCCsGAQUFBzABhhdo
# dHRwOi8vb2NzcC5zZWN0aWdvLmNvbTANBgkqhkiG9w0BAQwFAAOCAgEATJtlWPrg
# ec/vFcMybd4zket3WOLrvctKPHXefpRtwyLHBJXfZWlhEwz2DJ71iSBewYfHAyTK
# x6XwJt/4+DFlDeDrbVFXpoyEUghGHCrC3vLaikXzvvf2LsR+7fjtaL96VkjpYeWa
# OXe8vrqRZIh1/12FFjQn0inL/+0t2v++kwzsbaINzMPxbr0hkRojAFKtl9RieCqE
# eajXPawhj3DDJHk6l/ENo6NbU9irALpY+zWAT18ocWwZXsKDcpCu4MbY8pn76rSS
# ZXwHfDVEHa1YGGti+95sxAqpbNMhRnDcL411TCPCQdB6ljvDS93NkiZ0dlw3oJok
# nk5fTtOPD+UTT1lEZUtDZM9I+GdnuU2/zA2xOjDQoT1IrXpl5Ozf4AHwsypKOazB
# pPmpfTXQMkCgsRkqGCGyyH0FcRpLJzaq4Jgcg3Xnx35LhEPNQ/uQl3YqEqxAwXBb
# mQpA+oBtlGF7yG65yGdnJFxQjQEg3gf3AdT4LhHNnYPl+MolHEQ9J+WwhkcqCxuE
# dn17aE+Nt/cTtO2gLe5zD9kQup2ZLHzXdR+PEMSU5n4k5ZVKiIwn1oVmHfmuZHaR
# 6Ej+yFUK7SnDH944psAU+zI9+KmDYjbIw74Ahxyr+kpCHIkD3PVcfHDZXXhO7p9e
# IOYJanwrCKNI9RX8BE/fzSEceuX1jhrUuUAxggZqMIIGZgIBATBpMFQxCzAJBgNV
# BAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxKzApBgNVBAMTIlNlY3Rp
# Z28gUHVibGljIENvZGUgU2lnbmluZyBDQSBSMzYCEQD0Gwgn3Lm6AdRaYgUNyg/I
# MA0GCWCGSAFlAwQCAQUAoIGEMBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJ
# KoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQB
# gjcCARUwLwYJKoZIhvcNAQkEMSIEIDJ6T8i/3zHHbLMp7ru4mIR5Elk6/TKmeGKn
# eW34UzvtMA0GCSqGSIb3DQEBAQUABIICAEIAwb48ks5RM4ELcZuDWVN5XkvBH+Lv
# CvWoCPWI4D1Y7sUbFzOChNi+/WMXTU6mqERh1tPEPwgsF6eh9T5O8nHw4/y5cXOU
# UEADODAYi45iF8FCueJqVulkGy6fJ+M4fBbxxrw68GwV6dwSfCcJJ2nVHDJD1aKk
# SFMEmFRmdO6uZThQcFy29gD1xLoq4lXD0D+i/13rcqP8cpEKuMsIaRoNaYoeDEaE
# nxY3u2n3H1XX0gBsFXzCXxrvWk/h86J5/25PC8uns5rs38XRcbx7jambTnb2CZf3
# tzmjqS0Hyck69p8wHNXOx+eW5eG4D3qE8jhNvIj9bReLrSguBKYtevuiyldO0cqg
# 3GWpipFQgr1dir+8pnUZw2MKDxX+Y3fcMwjKAp54HBNOtBwalA/exfearV4ID4cW
# bLHqN/5ogd4g1Kj/eWr+bniBriFHNH8t77IUN2Emoyd2II4YfhvGNa43XrnesQHq
# T5Kc7JzoPkT+WEyTupC1rmZPlxTldBOWk7QXQhCa1w/dv7ka2628cNfOJQKzKZ8w
# wdr1KP9MOfyQg1u2UA0rbDjGwPRXrOv12jcpoPsLvQtS84LHJeqroK02RXy39K24
# Y+9mo+96+Rn7qD8Z5ziMLDjagDKOjop0zvryi3hciTLuyedjoUzmOuvhvqwEA419
# TK6k3WRScqG8oYIDSzCCA0cGCSqGSIb3DQEJBjGCAzgwggM0AgEBMIGRMH0xCzAJ
# BgNVBAYTAkdCMRswGQYDVQQIExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcT
# B1NhbGZvcmQxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDElMCMGA1UEAxMcU2Vj
# dGlnbyBSU0EgVGltZSBTdGFtcGluZyBDQQIQOUwl4XygbSeoZeI72R0i1DANBglg
# hkgBZQMEAgIFAKB5MBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcN
# AQkFMQ8XDTI0MDQxODE4MzAyNFowPwYJKoZIhvcNAQkEMTIEMB9MdnKqlD+7Tq5U
# LE0E8M95Oj4lN3+7Reo6OrwBBEjYC4nd6s/4FQioMoPE2nyQ9DANBgkqhkiG9w0B
# AQEFAASCAgB+bsIbg1Zc/nHm5C+JUDHWHNnFlEbwYowGy1+2UztbS7v7p8gun9v+
# R+RHTB9LgahVl+jjhbPLcQgoyw3un2HeIBwglaVDmBWGlnIcX00VJneifHt3LzN/
# tM0AK1Ia9ec5R0SXklb9O1sssuvO/sY9dtn9EqsrKFCkTZXSLEv/yndRnCCCvLVp
# 4aPc1U7Kc3THzKVQ5Xq6c2Uys+R4VPsjkAkC3Wu8HJd49RqkBuPKFloNVpyrqBOA
# xbFOPmIJ78s32kQ9khZrrV8lXf/rui+C/cnjWP2tHAc8UQMOrzQF1UqlqMhvjPJA
# YXsgWIhcAjUl5v5Qn4tHsgEk5IKXknfbn3N/XF0P5tyExHkYWzoO4c9s+43pg/X+
# CTS7ExjEfq3Z1lTxtSD5/h/S4wQF80z67uh+UcbfIrKYk8kFuSVkHzHAB4173hFW
# KIPPZYbV2qsh7b7Z91V9val5enFZd4RKjp2uhiULhijlk33NAnFhBI/zfRurUZcT
# x5MakP9zpn9nJ+db9s1AUs2AWcEApWzMHKQIwk2dgEt59vWXh0xGWA9LspyytexE
# MckbDOUeN/28PsjXP3ksj6egxV7W1ABpOOYfOuyilWu7i+nTvfHkdJj7ECK9ZBKG
# PK57cfLWVPSOAqhNQ+uDaUyF/r/XI2wg8TMcTpkG9qesBJaSU3oIMQ==
# SIG # End signature block
