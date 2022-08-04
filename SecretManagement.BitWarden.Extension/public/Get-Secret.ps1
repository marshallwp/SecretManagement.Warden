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
        [hashtable] $AdditionalParameters,
        [switch] $AsPlainText
    )

    [System.Collections.Generic.List[string]]$SearchParams = @("get","item")
    
    if ( $Name ) {
        $SearchParams.Add( $Name )
    }

    if ( $AdditionalParameters.ContainsKey('organizationid')) {
        $SearchParams.Add( '--organizationid' )
        $SearchParams.Add( $AdditionalParameters['organizationid'] )
    }

    $Result = Invoke-BitwardenCLI @SearchParams -AsPlainText:$AsPlainText

    if ( ! $Result ) {
        throw [System.Management.Automation.ItemNotFoundException]"No results returned"
    } elseif ( $Result.Count -gt 1 ) {
        throw 'Multiple entries returned'
    }

    switch ($Result.type) {
        "SecureNote" { return $Result.notes; break }
        "Login" {
            # Output login as an ordered hashtable.  This allows us to support credentials that lack a username and therefore cannot output a PSCredential.
            $login = [ordered]@{}
            foreach($property in ($Result.login | Get-Member -MemberType NoteProperty).Name) {
                $login[$property] = $Result.login.$property
            }
            return $login
        }
        default {throw [System.NotImplementedException]"Somehow you got to a place that doesn't exist."; break}
    }
}

# [BitwardenItemType]::SecureNote {return $Result.notes; break}
