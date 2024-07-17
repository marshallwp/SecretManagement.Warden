# . '..\classes\BitwardenEnums.ps1'
# . '..\classes\BitwardenPasswordHistory.ps1'
# . '.\ConvertTo-BWEncoding.ps1'

[version]$MinSupportedVersion = '2022.8.0'
[version]$CurrentVersion
# check if we should use a specific bw.exe
if ( $env:BITWARDEN_CLI_PATH -and ($BitwardenCLI = Get-Command $env:BITWARDEN_CLI_PATH -CommandType Application -ErrorAction SilentlyContinue) ) {
    $CurrentVersion = $BitwardenCLI.Version
}
elseif ( $BitwardenCLI = Get-Command -Name bw.exe -CommandType Application -ErrorAction Ignore ) {
    #? Scoop shims eliminate version numbers, so we ask scoop for the true version.
    if( $BitwardenCLI.Version -eq '0.0.0.0' -and (Get-Command scoop -ErrorAction Ignore) ) {
        $CurrentVersion = (scoop list bitwarden-cli 6> $null).Version ?? $BitwardenCLI.Version
    }
    #? WinGet shims have the wrong version, and the winget cli has output that is difficult to parse reliably. Therefore, ask bw.exe what version it is.
    elseif( $BitwardenCLI.Source -like "*\WinGet\Links\bw.exe" -or <# Machine Scope #>
            $BitwardenCLI.Source -like "*\Winget\Packages\*\bw.exe" <# User Scope #> ) {
        $CurrentVersion = .$BitwardenCLI.Source --version
    }
    else {
        $CurrentVersion = $BitwardenCLI.Version
    }
}
else {
    if( $IsWindows ) { $platform = "windows" }
    elseif ( $IsMacOS ) { $platform = "macos" }
    else { $platform = "linux" }

    Write-Error "No Bitwarden CLI found in your path, either specify `$env:BITWARDEN_CLI_PATH or put bw.exe in your path.  If the CLI is not installed, you can install it using scoop, chocolatey, npm, snap, or winget. You can also download it directly from: https://vault.bitwarden.com/download/?app=cli&platform=$platform" -ErrorAction Stop
}

if ( $BitwardenCLI -and $CurrentVersion -lt $MinSupportedVersion ) {
    Write-Warning "Your Bitwarden CLI is version $CurrentVersion and is out of date. Please upgrade to at least version $MinSupportedVersion."
}
elseif ( $BitwardenCLI -and $CurrentVersion -eq '2023.12.1') {
    Write-Warning "Your Bitwarden CLI is version $CurrentVersion. This version of the CLI has a known issue affecting bw list, which is used to check if the vault is unlocked due to bug: https://github.com/bitwarden/clients/issues/2729. It is `e[3mstrongly`e[23m recomended you move to another version. Otherwise you will need to constantly logout and login again."
}
elseif ( $BitwardenCLI -and $CurrentVersion -in ('2024.6.1','2024.7.0')) {
    Write-Warning "Your Bitwarden CLI is version $CurrentVersion. Versions 2024.6.1 & 2024.7.0 of the CLI have a known issue with the unlock command on some systems.  It is reccomnded that you move to another version.  See: https://github.com/bitwarden/clients/issues/9919"
}


$__Commands = @{
    login          = '--apikey --check --raw --method --code --sso  --help'
    logout         = '--help'
    lock           = '--help'
    unlock         = '--check --raw --help'
    sync           = '--force --last --help'
    list           = '--search --url --folderid --collectionid --organizationid --trash --help'
    get            = '--itemid --output --organizationid --help'
    create         = '--file --itemid --organizationid --help'
    edit           = '--organizationid --help'
    delete         = '--itemid --organizationid --permanent --help'
    restore        = '--help'
    share          = '--help'
    confirm        = '--organizationid --help'
    import         = '--formats --help'
    export         = '--output --format --organizationid --help'
    generate       = '--uppercase --lowercase --capitalize --number --special --passphrase --length --words --minNumber --minSpecial --separator --includeNumber --ambiguous --help'
    encode         = '--help'
    config         = '--web-vault --api --identity --icons --notifications --events --help'
    update         = '--raw --help'
    completion     = '--shell --help'
    status         = '--help'
    send           = '--file --deleteInDays --hidden --name --notes --fullObject --help'
}

$__CommandAutoComplete = @{
    list           = 'items folders collections organizations org-collections org-members'
    get            = 'item username password uri totp exposed attachment folder collection org-collection organization template fingerprint send'
    create         = 'item attachment folder org-collection'
    edit           = 'item item-collections folder org-collection'
    delete         = 'item attachment folder org-collection'
    restore        = 'item'
    confirm        = 'org-member'
    import         = '1password1pif 1passwordwincsv ascendocsv avastcsv avastjson aviracsv bitwardencsv bitwardenjson blackberrycsv blurcsv buttercupcsv chromecsv clipperzhtml codebookcsv dashlanejson encryptrcsv enpasscsv enpassjson firefoxcsv fsecurefsk gnomejson kasperskytxt keepass2xml keepassxcsv keepercsv lastpasscsv logmeoncecsv meldiumcsv msecurecsv mykicsv operacsv padlockcsv passboltcsv passkeepcsv passmanjson passpackcsv passwordagentcsv passwordbossjson passworddragonxml passwordwallettxt pwsafexml remembearcsv roboformcsv safeincloudxml saferpasscsv securesafecsv splashidcsv stickypasswordxml truekeycsv upmcsv vivaldicsv yoticsv zohovaultcsv'
    config         = 'server'
    template       = 'item item.field item.login item.login.uri item.card item.identity item.securenote folder collection item-collections org-collection'
    send           = 'list template get receive create edit remove-password delete'
    '--method'     = '0 1 3'
    '--format'     = 'csv json'
    '--shell'      = 'zsh'
}

$__CommonParams    = '--pretty --raw --response --quiet --nointeraction --session --version --help'

$__HasCompleter    = 'list get create edit delete restore confirm import config send ' +     # commands with auto-complete
                     'template ' +                                                      # template options
                     '--session ' +                                                     # provide session variable
                     '--method --code ' +                                               # login
                     '--search --url --folderid --collectionid --organizationid ' +     # list
                     '--itemid --output ' +                                             # get
                     '--format ' +                                                      # export
                     '--length --words --separator ' +                                  # generate
                     '--web-vault --api --identity --icons --notifications --events ' + # config
                     '--shell ' +                                                       # completion
                     '--file --deleteInDays --name --notes'                             # send


<#
.SYNOPSIS
 The Bitwarden command-line interface (CLI) is a powerful, fully-featured tool for accessing and managing your Vault.

.DESCRIPTION
 The Bitwarden command-line interface (CLI) is a powerful, fully-featured tool for accessing and managing your Vault.
 Most features that you find in other Bitwarden client applications (Desktop, Browser Extension, etc.) are available
 from the CLI. The Bitwarden CLI is self-documented. From the command line, learn about the available commands using:
 bw --help
#>
function Invoke-BitwardenCLI {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "", Justification = "Converting received plaintext password to SecureString")]
    Param()
    begin {
        if ( -not $BitwardenCLI ) {
            throw "Bitwarden CLI is not installed!"
        }
    }
    process {
        $ps = New-Object System.Diagnostics.Process
        $ps.StartInfo.Filename = $BitwardenCLI

        $args | ForEach-Object {
            Write-Verbose "Argument: $_"
            $ps.StartInfo.ArgumentList.Add($_)
        }

        if ( ( $ps.StartInfo.ArgumentList.Contains('unlock') -or $ps.StartInfo.ArgumentList.Contains('login') ) -and $ps.StartInfo.ArgumentList.Contains('--raw') ) {
            $ps.StartInfo.ArgumentList.RemoveAt( $ps.StartInfo.ArgumentList.IndexOf('--raw') )
        }

        if ( $_.Count -gt 0 ) {
            Write-Verbose "Pipleine input detected"
            $EncodedInput = ConvertTo-BWEncoding -InputObject $_
            if ( $ps.StartInfo.ArgumentList.Contains('encode') ) {
                return $EncodedInput
            } else {
                $ps.StartInfo.ArgumentList.Add( $EncodedInput )
            }
        }

        #! The error reader is unable to handle errors with prompts and will just stall instead.  Use the nointeraction argument when calling bw.exe to avoid the situation entirely.
        if(!$ps.StartInfo.ArgumentList.Contains('--nointeraction')) {
            $ps.StartInfo.ArgumentList.Add('--nointeraction')
        }
        Write-Verbose $ps.StartInfo.Arguments
        $ps.StartInfo.RedirectStandardOutput = $True
        $ps.StartInfo.RedirectStandardError = $True
        $ps.StartInfo.UseShellExecute = $False
        $ps.Start() | Out-Null
        $Result = $ps.StandardOutput.ReadToEnd()
        $BWError = $ps.StandardError.ReadToEnd()
        $ps.WaitForExit()

        if ($BWError) {
            switch -Wildcard ($BWError) {
                'Not found.' {
                    $ex = New-Object System.DirectoryServices.AccountManagement.NoMatchingPrincipalException "Not found."
                    Write-Error $ex -Category ObjectNotFound -ErrorAction Stop
                    break
                }
                'More than one result was found*' {
                    # Get the search term from the argument list by excluding commands and arguments
                    $searchTerm = $ps.StartInfo.ArgumentList | Where-Object {
                        $_ -notin ($__Commands.Keys) -and
                        $_ -notin ($__Commands[$ps.StartInfo.ArgumentList[0]] -split ' ') -and
                        $_ -notin ($__CommandAutoComplete[$ps.StartInfo.ArgumentList[0]] -split ' ') -and
                        $_ -notin ($__CommonParams -split ' ')
                    }

                    # Using list is way faster than looping get.
                    $errparse = Invoke-BitwardenCLI list items --search $searchTerm
                    $msg = @"
More than one result was found. Try getting a specific object by `id` instead.
The following objects were found:
$($errparse  | Format-Table ID, Name | Out-String )
"@
                    $ex = New-Object System.DirectoryServices.AccountManagement.MultipleMatchesException $msg
                    Write-Error -Exception $ex -Category InvalidResult -ErrorId "MultipleMatchesReturned" -ErrorAction Stop
                    break
                }
                'You are not logged in.' {
                    # If you are not logged in, but API Key information is present, login with that and rerun the command. This allows for silent resolution of this error when running in an automated fashion.
                    if($null -ne $env:BW_CLIENTID -and $null -ne $env:BW_CLIENTSECRET) {
                        Invoke-BitwardenCLI login --apikey --quiet
                        Invoke-BitwardenCLI @args
                        exit
                    }
                }
                '*mac failed.*' {
                    Write-Warning "bitwarden-cli is returning 'mac failed.' error(s) alongside content, which may result in invalid results. The short-term resolution is to logout and then login again. Some comments I've seen suggest you might try API key rotation."
                    break
                }
                default { Write-Error $BWError -ErrorAction Stop; break }
            }
        }

#region Workaround for 'bw get' ignoring the --organizationid flag.
        # This was moved above the check for a '--raw' argument so the workaround can work.
        try {
            [object[]]$JsonResult = $Result | ConvertFrom-Json -ErrorAction SilentlyContinue
        } catch {
            Write-Verbose "JSON Parse Message:"
            Write-Verbose $_.Exception.Message
        }

        # This is the main workaround code.
        if ( $ps.StartInfo.ArgumentList.Contains('get') -and $ps.StartInfo.ArgumentList.Contains('--organizationid') ) {
            # This requires an ordered argument list to work.
            [Guid]$org = [Guid]::Parse($ps.StartInfo.ArgumentList.Item($ps.StartInfo.ArgumentList.IndexOf('--organizationid')+1))
            $JsonResult = $JsonResult | Where-Object { $_.organizationId -eq $org }

            if(!$JsonResult) {
                $ex = New-Object System.DirectoryServices.AccountManagement.NoMatchingPrincipalException "Not found."
                Write-Error $ex -Category ObjectNotFound -ErrorAction Stop
            }
            elseif ( $ps.StartInfo.ArgumentList.Contains('--raw') ) {
                return $JsonResult | ConvertTo-Json -Depth 5 -Compress
            }
        }
#endregion Workaround for 'bw get' ignoring the --organizationid flag.

        # As passing exit codes to the parent process does not seem to be working, we pass $true and $false instead.
        if ( $ps.StartInfo.ArgumentList.Contains('--quiet') ) {
            if($ps.ExitCode -eq 0) { return $true } else { return $false }
        }

        # Help output tends to get truncated as the brackets can look kinda like JSON.
        if ( $ps.StartInfo.ArgumentList.Contains('--raw') -or
             $ps.StartInfo.ArgumentList.Contains('help') ) { return $Result }

        if ( $JsonResult -is [array] ) {
            $JsonResult.ForEach({
                if ( $_.type ) {
                    if ( $_.object -eq 'item' ) {
                        [BitwardenItemType]$_.type = [int]$_.type
                        $_.PSObject.TypeNames.Insert( 0, 'Bitwarden.' + $_.type )
                    } elseif ( $_.object -eq 'org-member' ) {
                        [BitwardenOrganizationUserType]$_.type = [int]$_.type
                        [BitwardenOrganizationUserStatus]$_.status = [int]$_.status
                    }
                }

                if ( $_.login ) {
                    if ( $_.login.username -and $_.login.password ) {
                        $pass = ConvertTo-SecureString -String $_.login.password -AsPlainText -Force

                        $_.login | Add-Member -MemberType NoteProperty -Name Credential -Value ([PSCredential]::new( $_.login.username, $pass ))
                    }

                    $_.login.uris.ForEach({ [BitwardenUriMatchType]$_.match = [int]$_.match })
                }

                if ( $_.passwordHistory ) {
                    [BitwardenPasswordHistory[]]$_.passwordHistory = $_.passwordHistory
                }

                $_
            })

        } else {
            # look for session key
            if ( $Result -and $Result -like '*--session*' ) {
                $env:BW_SESSION = $Result.Trim().Split(' ')[-1]
                return $Result[0]
            }
            #? Is the Result an empty JSON array?  Then return an empty array.
            elseif ( $Result -eq '[]' ) {
                return ,@()
            }
            else {
                return $Result
            }
        }
    }
}

$BitwardenCLIArgumentCompleter = {
    param(
        $WordToComplete,
        $CommandAst,
        $CursorPosition
    )

    function ConvertTo-ArgumentsArray {
        function __args { $args }
        Invoke-Expression "__args $args"
    }

    $InformationPreference = 'Continue'

    # trim off the command name and the $WordToComplete
    $ArgumentsList = $CommandAst -replace '^bw(.exe)?\s+' -replace "\s+$WordToComplete$"

    # split the $ArgumentsList into an array
    [string[]]$ArgumentsArray = ConvertTo-ArgumentsArray $ArgumentsList

    # check for the current command, returns first command that appears in the
    # $ArgumentsArray ignoring parameters any other strings
    $CurrentCommand = $ArgumentsArray |
        Where-Object { $_ -in $__Commands.Keys } |
        Select-Object -First 1

    # if the $ArgumentsArray is empty OR there is no $CurrentCommand then we
    # output all of the commands and common parameters that match the last
    # $WordToComplete
    if ( $ArgumentsArray.Count -eq 0 -or -not $CurrentCommand ) {
        return $__Commands.Keys + $__CommonParams.Split(' ') |
            Where-Object { $_ -notin $ArgumentsArray } |
            Where-Object { $_ -like "$WordToComplete*" }
    }

    # if the last complete argument has auto-complete options then we output
    # the auto-complete option that matches the $LastChunk
    if ( $ArgumentsArray[-1] -in $__HasCompleter.Split(' ') ) {

        # if the last complete argument exists in the $__CommandAutoComplete
        # hashtable keys then we return the options
        if ( $ArgumentsArray[-1] -in $__CommandAutoComplete.Keys ) {
            return $__CommandAutoComplete[ $ArgumentsArray[-1] ].Split(' ') |
                Where-Object { $_ -like "$WordToComplete*" }
        }

        # if it doesn't have a key then we just want to pause for user input
        # so we return an empty string. this pauses auto-complete until the
        # user provides input.
        else {
            return @( '' )
        }
    }

    # finally if $CurrentCommand is set and the current option doesn't have
    # it's own auto-complete we return the remaining options in the current
    # command's auto-complete list
    return $__Commands[ $CurrentCommand ].Split(' ') |
        Where-Object { $_ -notin $ArgumentsArray } |
        Where-Object { $_ -like "$WordToComplete*" }
}

Register-ArgumentCompleter -CommandName 'Invoke-BitwardenCLI' -ScriptBlock $BitwardenCLIArgumentCompleter

# SIG # Begin signature block
# MIInJAYJKoZIhvcNAQcCoIInFTCCJxECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBcRMjVGZMHACG6
# mQaVSbEtHcrbK2UdbZ0NWGXDbYS1pqCCIBAwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# gjcCARUwLwYJKoZIhvcNAQkEMSIEIGHPxkAZod4SgNHBlctVYLT7YbwPrPouF+Jq
# znXvDc0CMA0GCSqGSIb3DQEBAQUABIICAJbki0CgMAXtA+Ooz062yD9h6fEMG18R
# tZxLZmT+iXdP6Tnu0YSUYUumb4dz2mhsdJLjEoYCOGT530iC3eprQifkgmviC//8
# xc3peuiEUSZVru66JQPfzIQdqX5w0EUJrRwZV2qICOKaTHl85gCXlIibrCSKevkK
# AjUT1FGUbmlDQzpD52nn1bMB2+OgJ3Ngtmu3HzRI0NwUMJz6Fl0oV5MrobYOVROp
# 2/334wlPjuzEouyO3+NVtL4dVplRybzN64+pdNSg1HaZlM7YgiQLpOzzpyPlxhZV
# /F+zzQze3d6NZXb4aNHfXZtb5eFRD5XdH3oiv2FpeEyU7XYgnyOuEDNggktbPpdC
# kE42SzI1GyweilI6gNMrP7YIIFFHU4eKUVESRRo7/MunCV/lhLAd5sjafbOyCegT
# TXm5nO6fy5f8L0GpvUTZ1TgJ7yuWhbCkuioQestHWz5myWbd2mpzDtnLUKCVHxxT
# 0R03h4cO+xp1I2Cc6cpfkSc+hfiVN3Qv1iRyn1H6vswpDMzzktjxO7mPQAb0IPZl
# Zkqyf6gM8S0IQW3onqa0aKOjty78B49EvwrVQoIZ7q/rsN3I4QBr2DOvCDa4bNsU
# sWSPtMVmXGu5cx59rjEVcPc130EyAL51J4NzMAYlja2PAI3Y3GhEBFtWt/Mc4+hB
# qahl5BWtU89CoYIDSzCCA0cGCSqGSIb3DQEJBjGCAzgwggM0AgEBMIGRMH0xCzAJ
# BgNVBAYTAkdCMRswGQYDVQQIExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcT
# B1NhbGZvcmQxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDElMCMGA1UEAxMcU2Vj
# dGlnbyBSU0EgVGltZSBTdGFtcGluZyBDQQIQOUwl4XygbSeoZeI72R0i1DANBglg
# hkgBZQMEAgIFAKB5MBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcN
# AQkFMQ8XDTI0MDcxNzIxMDQxOVowPwYJKoZIhvcNAQkEMTIEMFqsljPTBwcbDDBM
# 0CpOFnxZZT1HU0A1drr5NtkQn9G4IhxVynitEKytcxw1Zari7jANBgkqhkiG9w0B
# AQEFAASCAgBKONaEeKM0PkPJtYGDEWuC7WgkKTbs1szNhWphhwxkiCB09+I1kSUZ
# TMMzOEF7PDD70CrR9C5NSkY+RANqT+5MpoW97W6d1aaGt0wXDyNaPJ3KoSWXx7BG
# Qdxlpswgeu0C9i94FplCWancVR/X3gs9CBSv2X36jOuQznqKbUH5NyzyS5Bb/a7A
# kyyNae0Mzl3va74GZAVoFQc4znpOeIHeQxjzdlPwwqeXaqk8iUbLbNx4sru+clmF
# zgfgp/RDJq1cUcG2wV0pxe9skj5GGpF3H2VzbRqk4Q8uio/HHXe55t5Wl+77+PrO
# fpWgjrgJ4O8VzTYN6AJj0+3cfOX+zpaLhjnCC5KEFBVGX7a3C/uSCTeuWeNeIsTU
# VcM38O0BiK/0ar8ZCoAreHc939o6hK2Hqv2BDLkAoY9t98nQqbq7DSXlT40uQttN
# 4kPd3gt1UR9PjCWmMuEHjMXsEmYGiiRkKNqk3VE+kvrKi5zui4CFlLDfrq3CSC3b
# 85TG+wP6QmoltEuag3t49jtEDDLe4Z4QTGU5o3bCLE7PhGz2rIJvIybSRiJrShtS
# ExQyVVzhybriScyx7EsmXVEaJfRwlVUd+rr/8WK/Y79UEnZP+tKrSKztHbsz5Kj4
# Kd23UfU3tZgHPpY9Vvn1RWNDBLv4+/yJdDWs6K/t0S+2Df+upp1l9g==
# SIG # End signature block
