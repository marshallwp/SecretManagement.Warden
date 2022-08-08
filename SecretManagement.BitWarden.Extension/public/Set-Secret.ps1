function Set-Secret
{
    [CmdletBinding()]
    param (
        [string] $Name,
        # SecretManagement supports secrets of types: byte[], string, SecureString, PSCredential, and HashTable.
        [object] $Secret,
        [string] $VaultName,
        [hashtable] $AdditionalParameters
    )
    # UTF8 with BOM is supported in all versions of PowerShell.  Only Powershell 6+ supports UTF-8 Without BOM.
    # In Windows Powershell, UTF8 with BOM is called 'UTF8'.  In Powershell 6+ it is called 'utf8BOM'.
    $EncodingOfSecrets = if($AdditionalParameters.EncodingOfSecrets) {$AdditionalParameters.EncodingOfSecrets}
        elseif($PSEdition -eq "Desktop") { "UTF8" }
        else { "utf8BOM" }
    $ExportObjectsToSecureNotesAs = if($AdditionalParameters.ExportObjectsToSecureNotesAs) {$AdditionalParameters.ExportObjectsToSecureNotesAs} else {"JSON"}
    $MaximumObjectDepth = if($AdditionalParameters.MaximumObjectDepth) {$AdditionalParameters.MaximumObjectDepth} else {4}

    $OldSecret = Get-FullSecret -Name $Name -VaultName $VaultName -AdditionalParameters $AdditionalParameters
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
                            $OldSecret.login.username = if($Secret.UserName -and $Secret.UserName.GetType().Name -eq "SecureString")
                                { ConvertFrom-SecureString $Secret.UserName -AsPlainText } else { [string]$Secret.UserName }
                        }
                        if($Secret.Password -or $IsNewItem) {
                            $OldSecret.login.password = if($Secret.Password -and $Secret.Password.GetType().Name -eq "SecureString") 
                                { ConvertFrom-SecureString $Secret.Password -AsPlainText } else { [string]$Secret.Password }
                        }
                        if($Secret.uris) { $OldSecret.login.uris = @([string]$Secret.uris) } elseif($IsNewItem) { $OldSecret.login.uris = @() }
                        if($Secret.totp -or $IsNewItem) {
                            $OldSecret.login.totp = if($Secret.totp -and $Secret.totp.GetType().Name -eq "SecureString")
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
                        $OldSecret.login.$Field = if( $Secret.GetType().Name -eq "SecureString" )  { ConvertFrom-SecureString $Secret -AsPlainText } else { $Secret }
                    }
                    elseif( $Field -ieq "URIs" ) {
                        $OldSecret.login.uris = @( if( $Secret.GetType().Name -eq "SecureString" )  { ConvertFrom-SecureString $Secret -AsPlainText } else { $Secret } )
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
                            $Secret | Export-Clixml -Encoding $EncodingOfSecrets -Depth $MaximumObjectDepth -Path $tmp
                            $OldSecret.notes = $ObjTemplate -f "CliXml", (Get-Content -Path $tmp -Encoding $EncodingOfSecrets -Raw)
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
                                $OldSecret.card.$_ = if($Secret.$_ -and $Secret.$_.GetType().Name -eq "SecureString")
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
                                $OldSecret.identity.$_ = if($Secret.$_ -and $Secret.$_.GetType().Name -eq "SecureString")
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
