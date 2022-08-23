# . '..\classes\BitwardenEnums.ps1'
# . '..\classes\BitwardenPasswordHistory.ps1'
# . '.\ConvertTo-BWEncoding.ps1'

[version]$SupportedVersion = '2022.8.0'
[version]$CurrentVersion
# check if we should use a specific bw.exe
if ( $env:BITWARDEN_CLI_PATH -and ($BitwardenCLI = Get-Command $env:BITWARDEN_CLI_PATH -CommandType Application -ErrorAction SilentlyContinue) ) {
    $CurrentVersion = $BitwardenCLI.Version
}
elseif ( $BitwardenCLI = Get-Command -Name bw.exe -CommandType Application -ErrorAction Ignore ) {
    #? Scoop shims eliminate version numbers, so we ask scoop for the true version.
    if( $BitwardenCLI.Version -eq '0.0.0.0' -and (Get-Command scoop -ErrorAction Ignore) ) {
        $CurrentVersion = (scoop info bitwarden-cli).Installed ?? $BitwardenCLI.Version
    } else {
        $CurrentVersion = $BitwardenCLI.Version
    }
}
else {
    if( $IsWindows ) { $platform = "windows" }
    elseif ( $IsMacOS ) { $platform = "macos" }
    else { $platform = "linux" }

    Write-Error "No Bitwarden CLI found in your path, either specify `$env:BITWARDEN_CLI_PATH or put bw.exe in your path.  If the CLI is not installed, you can install it using scoop, chocolatey, npm, or snap. You can also download it directly from: https://vault.bitwarden.com/download/?app=cli&platform=$platform" -ErrorAction Stop
}

if ( $BitwardenCLI -and $CurrentVersion -lt $SupportedVersion ) {
    Write-Warning "Your Bitwarden CLI is version $CurrentVersion and out of date, please upgrade to at least version $SupportedVersion."
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
    generate       = '--uppercase --lowercase --number --special --passphrase --length --words --separator --help'
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
                    $errparse = @()
                    $BWError.Split("`n") | Select-Object -Skip 1 | ForEach-Object {
                        $errparse += Invoke-BitwardenCLI get item $_
                    }
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

        if ( $ps.StartInfo.ArgumentList.Contains('--raw') ) { return $Result }


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
