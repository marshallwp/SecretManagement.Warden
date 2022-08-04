<#
.SYNOPSIS
    Retrieves a single secret from the vault.
.DESCRIPTION
    Retrives a single secret from the vault.  Corresponds with the "bw get" functionality of the CLI.
#>
function Get-Secret {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('ID')][string] $Name,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $VaultName,
        [Parameter(ValueFromPipelineByPropertyName)]
        [hashtable] $AdditionalParameters
    )

    [System.Collections.Generic.List[string]]$SearchParams = @("get")
    
    if($AdditionalParameters.ContainsKey('ObjectType') -and $AdditionalParameters.ObjectType -in @("item", "username", "password", "uri", "totp", "notes",
    "attachment", "folder", "collection", "org-collection", "organization", "template", "fingerprint", "send")) {
        $SearchParams.Add($AdditionalParameters.ObjectType)
    }
    
    if ( $Name ) {
        $SearchParams.Add( $Name )
    }

    if ( $AdditionalParameters.ContainsKey('organizationid')) {
        $SearchParams.Add( '--organizationid' )
        $SearchParams.Add( $AdditionalParameters['organizationid'] )
    }

    $Result = Invoke-BitwardenCLI @SearchParams

    if ( ! $Result ) {
        throw [System.Management.Automation.ItemNotFoundException]"No results returned"
    } elseif ( $Result.Count -gt 1 ) {
        throw 'Multiple entries returned'
    }

    switch ($Result.type) {
        [BitwardenItemType]::SecureNote {return $Result.notes; break}
        [BitwardenItemType]::Login {
            if($null -ne $Result.login.credential) {
                # Credential is PSCredential
                return $Result.login.credential
            } elseif($null -ne $Result.login.password) {
                # Password is SecureString
                return $Result.login.password
            } else {
                throw [System.Management.Automation.PropertyNotFoundException]"Item was found, but neither credential nor password exist."
            }
        }
        default {throw [System.NotImplementedException]"Somehow you got to a place that doesn't exist."; break}
    }
}