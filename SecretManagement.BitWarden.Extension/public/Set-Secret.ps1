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
    # UTF8 With BOM is supported in all versions of PowerShell.  Only Powershell 6+ supports UTF-8 Without BOM.
    $EncodingOfSecrets = if($AdditionalParameters.EncodingOfSecrets) {$AdditionalParameters.EncodingOfSecrets} else {"utf8BOM"}
    $ExportObjectsToSecureNotesAs = if($AdditionalParameters.ExportObjectsToSecureNotesAs) {$AdditionalParameters.ExportObjectsToSecureNotesAs} else {"JSON"}
    $MaximumObjectDepth = if($AdditionalParameters.MaximumObjectDepth) {$AdditionalParameters.MaximumObjectDepth} else {2}

    $OldSecret = Get-FullSecret -Name $Name -VaultName $VaultName -AdditionalParameters $AdditionalParameters
    $IsNewSecret = $false

    # If OldSecret does not exist, assume this is a new secret.
    if( ! $OldSecret ) {
        $IsNewSecret = $true
        $OldSecret = Invoke-BitwardenCLI get template item -AsPlainText
        $OldSecret.name = $Name

        switch( $Secret.GetType().Name ) {
            "PSCredential" {
                $OldSecret.type = [BitwardenItemType]::Login
                $OldSecret.login = Invoke-BitwardenCLI get template item.login -AsPlainText
                break
            }
            { "String","SecureString" -contains $Secret.GetType().Name } {
                $Field = Read-Host -Prompt "Is this $($Secret.GetType().Name) a UserName, Password or SecureNote?"
                
                if( $Field -iin "UserName","Password" ) {
                    $OldSecret.type = [BitwardenItemType]::Login
                    $OldSecret.login = Invoke-BitwardenCLI get template item.login -AsPlainText
                } elseif( $Field -ieq "SecureNote" ) {
                    $OldSecret.type = [BitwardenItemType]::SecureNote
                    $OldSecret.securenote = Invoke-BitwardenCLI get template item.securenote -AsPlainText
                } else {
                    $ex = New-Object System.Management.Automation.Host.PromptingException "$Field is not a valid option!"
                    Write-Error -Exception $ex -Category InvalidArgument -ErrorId "InvalidUserInput" -ErrorAction Stop
                }
                break
            }
            "HashTable" {
                if ( ![String]::IsNullOrEmpty( $Secret.UserName ) -or $null -ne $Secret.Password ) {
                    $OldSecret.type = [BitwardenItemType]::Login
                    $OldSecret.login = Invoke-BitwardenCLI get template item.login -AsPlainText
                    break
                }
                # elseif ( ![String]::IsNullOrEmpty( $Secret.UserName ) -or $null -ne $Secret.Password ) {
                #     $ex = New-Object System.Management.Automation.PSInvalidCastException "Input [HashTable]Secret looks like a Login, but does not include both UserName and Password."
                #     Write-Error -Exception $ex -Category InvalidOperation -CategoryReason "Hashtable is missing either UserName or Password and cannot be created." -ErrorAction Stop
                # }
                else {
                    $OldSecret.type = [BitwardenItemType]::SecureNote
                    $OldSecret.securenote = Invoke-BitwardenCLI get template item.securenote -AsPlainText
                    break
                }
                break
            }
        }
    }

    # Do things differently based on what type of secret we're editing.
    switch($OldSecret.type) {
        [BitwardenItemType]::Login {
            # Do things differently based on what type of information the new secret is.
            switch($Secret.GetType().Name) {
                "PSCredential" {
                    $OldSecret.login.username = $Secret.UserName
                    $OldSecret.login.password = ConvertFrom-SecureString $Secret.Password -AsPlainText
                    break
                }
                "HashTable" {
                    if ( ![String]::IsNullOrEmpty( $Secret.UserName ) -or $null -ne $Secret.Password ) {
                        if ( ![String]::IsNullOrEmpty( $Secret.UserName ) ) { $OldSecret.login.username = $Secret.UserName }
                        if ( $null -ne $Secret.Password ) {
                            $OldSecret.login.password = if($Secret.Password.GetType().Name -eq "SecureString") 
                                { ConvertFrom-SecureString $Secret.Password -AsPlainText } else { $Secret.Password }
                        }
                    }
                    else {
                        $ex = New-Object System.Management.Automation.PSInvalidCastException "Input [HashTable]Secret could not be cast to any part of a Bitwarden Login."
                        Write-Error -Exception $ex -Category InvalidOperation -CategoryReason "Hashtable contains neither UserName nor Password." -ErrorAction Stop
                    }
                    break
                }
                { "String","SecureString" -contains $Secret.GetType().Name } {
                    $Field = Read-Host -Prompt "Does this $($Secret.GetType().Name) update the UserName or the Password?"
                    
                    if($Field -iin "UserName","Password") {
                        $OldSecret.login.$Field = if( $Secret.GetType().Name -eq "SecureString" )  { ConvertFrom-SecureString $Secret -AsPlainText } else { $Secret }
                    }
                    else {
                        $ex = New-Object System.Management.Automation.Host.PromptingException "$Field is not a valid option!"
                        Write-Error -Exception $ex -Category InvalidArgument -ErrorId "InvalidUserInput" -ErrorAction Stop
                    }
                    break
                }
                default { 
                    $ex = New-Object System.Management.Automation.PSInvalidCastException "Casting data of $($Secret.GetType().Name) type to a Bitwarden Login is not supported."
                    Write-Error -Exception $ex -Category InvalidType -ErrorId "InvalidCast" -ErrorAction Stop
                    break
                }
            }
        }
        [BitwardenItemType]::SecureNote {
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
        }
    }

    [System.Collections.Generic.List[string]]$CmdParams = @("edit","item",$Name)

    $NewSecret = $OldSecret | ConvertTo-Json -Depth 4 -Compress | ConvertTo-BWEncoding
    $CmdParams.Add( $NewSecret )

    if ( $AdditionalParameters.ContainsKey('organizationid')) {
        $CmdParams.Add( '--organizationid' )
        $CmdParams.Add( $AdditionalParameters['organizationid'] )
    }

    Invoke-BitwardenCLI @CmdParams
}
