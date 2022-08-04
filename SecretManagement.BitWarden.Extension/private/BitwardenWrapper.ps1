# using module '..\classes\BitwardenEnums.ps1'
# using module '..\classes\BitwardenPasswordHistory.ps1'

[version]$SupportedVersion = '1.16'

# check if we should use a specific bw.exe
if ( $env:BITWARDEN_CLI_PATH ) {
    $BitwardenCLI = Get-Command $env:BITWARDEN_CLI_PATH -CommandType Application -ErrorAction SilentlyContinue
} else {
    $BitwardenCLI = Get-Command -Name bw.exe -CommandType Application -ErrorAction SilentlyContinue
}

if ( -not $BitwardenCLI ) {
    if([System.Environment]::OSVersion.Platform -eq "Win32NT") { $platform = "windows" }
    elseif ($IsMacOS) { $platform = "macos" }
    else { $platform = "linux" }

    Write-Warning "No Bitwarden CLI found in your path, either specify `$env:BITWARDEN_CLI_PATH or put bw.exe in your path.  If the CLI is not installed, you can install it using scoop, chocolatey, npm, or snap. You can also download it directly from: https://vault.bitwarden.com/download/?app=cli&platform=$platform"
}

if ( $BitwardenCLI -and $BitwardenCLI.Version -lt $SupportedVersion ) {
    Write-Warning "Your Bitwarden CLI is version $($BitwardenCLI.Version) and out of date, please upgrade to at least version $SupportedVersion."
}


$__Commands = @{
    login          = '--raw --method --code --sso --check --help'
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
function Invoke-BitwardenCLI ([switch]$AsPlainText) {
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
        $ps.WaitForExit(1000) | Out-Null


        if ($BWError) {
            switch -Wildcard ($BWError) {
                '*session*' {
                    Write-Verbose "Wrong Password, Try again $PSBoundParameters"
                    Invoke-BitwardenCLI login
                }
                'You are not logged in.' {
                    if($null -ne $env:BW_CLIENTID -and $null -ne $env:BW_CLIENTSECRET) {
                        Invoke-BitwardenCLI login --apikey
                    }
                    else { Invoke-BitwardenCLI login }
                }
                'Session key is invalid.' {
                    Write-Verbose $BWError
                }
                'Vault is locked.' {
                    Write-Warning $BWError
                    Unlock-SecretVault
                }
                'More than one result was found*' {
                    $errparse = @()
                    $BWError.Split("`n") | Select-Object -Skip 1 | ForEach-Object {
                        $errparse += Invoke-BitwardenCLI get item $_
                    }
                    Write-Error @"
More than one result was found. Try getting a specific object by `id` instead. The following objects were found:
                    $($errparse  | Format-Table ID, Name | Out-String )
"@ -ErrorAction Stop
                }
                default { Write-Error $BWError }
            }
        }

        if ( $ps.StartInfo.ArgumentList.Contains('--raw')) { return $Result }

        try {
            [object[]]$JsonResult = $Result | ConvertFrom-Json -ErrorAction SilentlyContinue
        } catch {
            Write-Verbose "JSON Parse Message:"
            Write-Verbose $_.Exception.Message
        }

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

                if ( $_.notes -and !$AsPlainText) {
                    if ( ![String]::IsNullOrEmpty($_.notes) ) { $_.notes = ConvertTo-SecureString -String $_.notes -AsPlainText -Force }
                    else { $_.notes = New-Object System.Security.SecureString }
                }

                if ( $_.login ) {
                    if ( ![String]::IsNullOrEmpty($_.login.password) -and !$AsPlainText ) {
                        $_.login.password = ConvertTo-SecureString -String $_.login.password -AsPlainText -Force
                    } elseif ( !$AsPlainText ) {
                        $_.login.password = New-Object System.Security.SecureString
                    }

                    if ( $_.login.username -and $_.login.password ) {
                        if($AsPlainText){ $pass = ConvertTo-SecureString -String $_.login.password -AsPlainText -Force }
                        else { $pass = $_.login.password }

                        $_.login | Add-Member -MemberType NoteProperty -Name Credential -Value ([PSCredential]::new( $_.login.username, $pass ))
                    }

                    $_.login.uris.ForEach({ [BitwardenUriMatchType]$_.match = [int]$_.match })
                }

                if ( $_.passwordHistory ) {
                    [BitwardenPasswordHistory[]]$_.passwordHistory = $_.passwordHistory
                    <#$_.passwordHistory.ForEach({
                        $_.password = ConvertTo-SecureString -String $_.password -AsPlainText -Force
                    })#>
                }

                if ( $_.identity.ssn -and !$AsPlainText) {
                    $_.identity.ssn = ConvertTo-SecureString -String $_.identity.ssn -AsPlainText -Force
                }

                if ( $_.fields ) {
                    $_.fields.ForEach({
                        [BitwardenFieldType]$_.type = [int]$_.type
                        if ( $_.type -eq [BitwardenFieldType]::Hidden -and !$AsPlainText ) {
                            $_.value = ConvertTo-SecureString -String $_.value -AsPlainText -Force
                        }
                    })
                }
                $_
            })

        } else {
            # look for session key
            if ( $Result -and $Result -like '*--session*' ) {
                $env:BW_SESSION = $Result.Trim().Split(' ')[-1]
                return $Result[0]
            } elseif ($ps.StartInfo.ArgumentList.Contains('password') -and !$AsPlainText) {
                return ConvertTo-SecureString -String ($Result -join ' ') -AsPlainText -Force
            } else {
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

<#
.SYNOPSIS
 Base64 encodes an object for Bitwarden CLI

.DESCRIPTION
 Base64 encodes an object for Bitwarden CLI
#>
function ConvertTo-BWEncoding {
    [CmdletBinding()]
    param(
        [Parameter( Mandatory, Position = 0, ValueFromPipeline )]
        [object]
        $InputObject
    )

    process {
        if ( $InputObject -isnot [string] ) {
            try {
                $InputObject | ConvertFrom-Json > $null
                Write-Verbose 'Object is already a JSON string'
            } catch {
                Write-Verbose 'Converting object to JSON'
                $InputObject = ConvertTo-Json -InputObject $InputObject -Compress
            }
        }

        try {
            [convert]::FromBase64String( $InputObject ) > $null
            Write-Verbose 'Object is already Base64 encoded'
            return $InputObject
        } catch {
            Write-Verbose 'Converting JSON to Base64 encoding'
            return [convert]::ToBase64String( [System.Text.Encoding]::UTF8.GetBytes( $InputObject ) )
        }
    }
}