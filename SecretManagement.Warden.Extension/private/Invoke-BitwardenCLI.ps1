# . '..\classes\BitwardenEnums.ps1'
# . '..\classes\BitwardenPasswordHistory.ps1'
# . '.\ConvertTo-BWEncoding.ps1'

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
        $ps.StartInfo.Filename = $BitwardenCLI.Source

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
                    $ex = New-Object System.Management.Automation.ItemNotFoundException "Not found."
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
                    $ex = New-Object System.Reflection.AmbiguousMatchException $msg
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
                $ex = New-Object System.Management.Automation.ItemNotFoundException "Not found."
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
            # ?Is the Result an empty JSON array?  Then return an empty array.
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
# MIIsEQYJKoZIhvcNAQcCoIIsAjCCK/4CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDPLDzLdaNgWJYm
# wq9783OZJL/+2leo7Q8YLTndBn8da6CCJSYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# CisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIEbsui+ZX9VKNQXEhVaI8F54hsc7
# CdfkOtO/xTVgu3EBMA0GCSqGSIb3DQEBAQUABIICAIeKy3r4PnlYmcuyFlHwfzPA
# CXtv/dAHQsr0JayRAquP7zYq4dzORdphybuk12NEkW+bEbHU026Kob3CkjZUCyVe
# m6E/ww1vdK4krLUlYdXjl7YtgMdhZrJ+Oj7MRel0NPG3/zQLjNP0+K8HjaCrwiGx
# +MQW3/WpkLYtfN5YuxiRlwdX+EZiJtLTnIE7QxYUayMK199Lq780+6SRBTVmtjq+
# SjIAU7piMtQlNGF3DuaP2TJ+j89lcHufZ+Z4yLwcsgV+nx2CyZ5KX7XT0sq/+z+v
# VtWB8ufyxs2AEHlZTAvvhzM2FHd3ILvCmnA1bkRhtugjMYYn7JNUVZeOq45V4jJz
# nejAZh+OMZxITBmrWoeJvtH0IERAGcM+TSwOuBNvxUbHSfNwEP3BmHU2JgocBw5e
# /ZwrZgFdcgBBD+zKHzRXUja7o5zL6CYFNi1CITy2VgAlwiwEL0G/fdDHtpun8ioh
# hCO6WEf4zyuiR9QCvLs46ZIIGwpC67i6D2PsVucDn3QU1ShjDRejQGdhVUF/wMJo
# 7c+7kOAe2EFqF4Q7M2CPrKubrUzyFox+u+cvhkWOudWivqisCn3/InwMUIAIm35R
# naL743T7bOo9cs1NHVK3y8BpncyvfSJFug42B6zolfpMqzUCE0jDdeXPEhkA5Sjp
# lnoFlX61Z7UER6QmNu1zoYIDIjCCAx4GCSqGSIb3DQEJBjGCAw8wggMLAgEBMGkw
# VTELMAkGA1UEBhMCR0IxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEsMCoGA1UE
# AxMjU2VjdGlnbyBQdWJsaWMgVGltZSBTdGFtcGluZyBDQSBSMzYCEDpSaiyEzlXm
# HWX8zBLY6YkwDQYJYIZIAWUDBAICBQCgeTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcN
# AQcBMBwGCSqGSIb3DQEJBTEPFw0yNDA5MjUyMTQ1MDhaMD8GCSqGSIb3DQEJBDEy
# BDAM5muJcDT575cHK71ZxFn0sjwpcPw9iMTHY9DMiPN0pzF4tnRyaGsJ2085ZmFU
# 0KAwDQYJKoZIhvcNAQEBBQAEggIAaytYaebLsDRpG5cPpVgswTzvvfknwk1y56w6
# aJwqHfOa00CG5te/VxcroA3uszoUFsM8gdsIaRIpKaqYN/GDucLH2P2i3D4K3jYf
# c3cUYA0QsRvf+gf23Ji82yB5m+WCqK6XNHnAWdfuEoUUR7mQ7yu5SQAa52emvM73
# fDf6DzS580y8IHhDVGVvxZFB4Gt3Yo7IqRziXmFSWViWYMoYQpxsb7KCaN0EE2BV
# gh2NPqEig7grc3pgPsTWgfYTNetacrmgzXV6RKohpD7WATiOycqWAkhbhtaQN97c
# 21iHtR200SrMbzpfL+ax/jH3LO2LD4xhH8XjlXB/iUgSBHbeT+MJZXLXou4EQ8z8
# Bgc2ZC56CBSCdM46ihAnS4h6sF0j9JNaX+BGlQlxNucQJo6Xnj9VWmrbcvyrkhDA
# u1jdLOfmT14H0FrKAKl5Hm+IV+wOmjrYru+L/fJyvoL0GcuHjEQ7ZsTiw3nkpl11
# 4YRKm12FzZ6xt+jXa0XY0l6G0tvWKUfzv7iJQEvbl6czR0W/s7Pb3KZPb+qeutyo
# rSP66ytJGI0BpTUE8GBimVdn3NhlIhcZgiVxwmam+aV2teeGWxxa93/d5/TZUwFS
# B6TNYxQuVfjzM0yGuZVbqo+F2X2zPnwNnU+Pl7WYKj+SDyFeQdiqq8X/ka8OHhpO
# dyELnhQ=
# SIG # End signature block
