<#
.SYNOPSIS
    Retrieves metadata about one or more secrets.  Can be piped to Get-Secret.
.DESCRIPTION
    Retrieves metadata about one or more secrets matching the filter.
.NOTES
    Per SecretManagement documentation, "The Get-SecretInfo cmdlet writes an array of Microsoft.PowerShell.SecretManagement.SecretInformation type objects to the output pipeline or an empty array if no matches were found."
#>
function Get-SecretInfo {
    [CmdletBinding()]
    param(
        [Alias('Name')][string] $Filter,
        [Alias('Vault')][string] $VaultName,
        [hashtable] $AdditionalParameters
    )

    # Enable Verbose Mode inside this script if passed from the wrapper.
    if($AdditionalParameters.ContainsKey('Verbose') -and ($AdditionalParameters['Verbose'] -eq $true)) {$script:VerbosePreference = 'Continue'}
    $AdditionalParameters = Merge-Defaults $AdditionalParameters
    Sync-BitwardenVault $AdditionalParameters.ResyncCacheIfOlderThan

    [System.Collections.Generic.List[string]]$CmdParams = @( "list", "items" )

    if ( $Filter ) {
        $CmdParams.Add( '--search' )
        $CmdParams.Add( $Filter )
    }

    if ( $AdditionalParameters.ContainsKey('organizationid')) {
        $CmdParams.Add( '--organizationid' )
        $CmdParams.Add( $AdditionalParameters['organizationid'] )
    }

    $Results = Invoke-BitwardenCLI @CmdParams

    foreach ( $secretInfo in $Results ) {
        if ( $secretInfo.type -eq [BitwardenItemType]::SecureNote -and !($Result.notes | Select-String -Pattern "(?<=PowerShellObjectRepresentation: )[^\n]*") ) {
            $type = [Microsoft.PowerShell.SecretManagement.SecretType]::SecureString
        }
        else {
            $type = [Microsoft.PowerShell.SecretManagement.SecretType]::Hashtable
        }

        $hashtable = [ordered]@{}
        if($secretInfo.login) { $hashtable['username'] = $secretInfo.login.username }
        foreach( $property in ($secretInfo | Select-Object -ExcludeProperty notes,login,id,type | Get-Member -MemberType NoteProperty).Name ) {
            $hashtable[$property] = $secretInfo.$property
        }

        [Microsoft.PowerShell.SecretManagement.SecretInformation]::new(
            $secretInfo.id,
            $type,
            $VaultName,
            $hashtable
        )
    }
}
