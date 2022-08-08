<#
.SYNOPSIS
    Retrieves a single secret from the vault.
.DESCRIPTION
    Retrives a single secret from the vault.  Corresponds with the "bw get" functionality of the CLI.
#>
function Get-Secret {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName, Mandatory=$true)]
        [Alias('ID')][string] $Name,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $VaultName,
        [Parameter(ValueFromPipelineByPropertyName)]
        [hashtable] $AdditionalParameters,
        [switch] $AsPlainText
    )

    # UTF8 with BOM is supported in all versions of PowerShell.  Only Powershell 6+ supports UTF-8 Without BOM.
    # In Windows Powershell, UTF8 with BOM is called 'UTF8'.  In Powershell 6+ it is called 'utf8BOM'.
    $EncodingOfSecrets = if($AdditionalParameters.EncodingOfSecrets) {$AdditionalParameters.EncodingOfSecrets}
        elseif($PSEdition -eq "Desktop") { "UTF8" }
        else { "utf8BOM" }

    [System.Collections.Generic.List[string]]$CmdParams = @("get","item")
    $CmdParams.Add( $Name ) #* Do not combine with the above line.  For some reason that causes the function to fail in production.

    if ( $AdditionalParameters.ContainsKey('organizationid')) {
        $CmdParams.Add( '--organizationid' )
        $CmdParams.Add( $AdditionalParameters['organizationid'] )
    }

    $Result = Invoke-BitwardenCLI @CmdParams -AsPlainText:$AsPlainText

    if ( !$Result ) {
        $ex = New-Object System.Management.Automation.ItemNotFoundException "Revise your search filter so it matches a secret in the vault."
        Write-Error -Exception $ex -Category ObjectNotFound -CategoryActivity 'Invoke-BitwardenCLI @CmdParams' -CategoryTargetName '$Result' -CategoryTargetType 'PSCustomObject' -ErrorAction Stop
    }

    switch ( $Result.type ) {
        "SecureNote" {
            $ObjType = ($Result.notes | Select-String -Pattern "(?<=PowerShellObjectRepresentation: )[^\n]*").Matches | Select-Object -First 1 -ExpandProperty Groups | Select-Object -First 1 -ExpandProperty Values
            if( ! $ObjType ) { 
                return $Result.notes
            }
            elseif( $ObjType -ieq "CliXml" ) {
                $tmp = New-TemporaryFile
                $Result.notes.Remove(0,$Result.notes.IndexOf("`n")+1) | Out-File -Encoding $EncodingOfSecrets -FilePath $tmp
                $obj = Import-Clixml -Encoding $EncodingOfSecrets -Path $tmp
                Remove-Item $tmp -Force
                return $obj
            }
            elseif( $ObjType -ieq "JSON" ) {
                $note = $Result.notes.Remove(0,$Result.notes.IndexOf("`n")+1)
                # Workaround to maintain compatability with PowerShell 5.x, which does not support the -AsHashTable parameter.
                if( Get-Command ConvertFrom-Json -ParameterName AsHashTable -ErrorAction Ignore ) {
                    return $note | ConvertFrom-Json -AsHashtable
                } else {
                    $note | ConvertFrom-Json | ConvertTo-Hashtable
                }
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
            return $Result.$_ | ConvertTo-HashTable
            break
        }
        default {throw [System.NotImplementedException]"Somehow you got to a place that doesn't exist."; break}
    }
}
