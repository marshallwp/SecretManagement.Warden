function Get-SecretInfo {
    [CmdletBinding()]
    param(
        [Alias('Name')][string] $Filter,
        [Alias('Vault')][string] $VaultName,
        [hashtable] $AdditionalParameters
    )

    $ResyncCacheIfOlderThan = $AdditionalParameters.ResyncCacheIfOlderThan ?? (New-TimeSpan -Hours 3)
    if((New-TimeSpan -Start (Invoke-BitwardenCLI sync --last | Get-Date)).TotalSeconds -gt $ResyncCacheIfOlderThan.TotalSeconds) {
        Invoke-BitwardenCLI sync | Out-Null
    }

    [System.Collections.Generic.List[string]]$CmdParams = @( "list", "items" )

    if ( $Filter ) {
        $CmdParams.Add( '--search' )
        $CmdParams.Add( $Filter )
    }

    if ( $AdditionalParameters.ContainsKey('folderName') ) {
        $folder = Invoke-BitwardenCLI get folder "$($AdditionalParameters.folderName)"
        $CmdParams.Add( '--folderid' )
        $CmdParams.Add( $folder.id )
    }

    $vaultSecretInfos = Invoke-BitwardenCLI @CmdParams

    foreach ( $vaultSecretInfo in $vaultSecretInfos ) {
        if ( $vaultSecretInfo.type -eq [BitwardenItemType]::Login ) {
            $type = [Microsoft.PowerShell.SecretManagement.SecretType]::PSCredential
        }
        else { 
            $type = [Microsoft.PowerShell.SecretManagement.SecretType]::SecureString 
        }

        $hashtable = [ordered]@{}
        foreach( $property in ($vaultSecretInfo | Select-Object -ExcludeProperty notes,login,name,type | Get-Member -MemberType NoteProperty).Name ) {
            $hashtable[$property] = $vaultSecretInfo.$property
        }

        [Microsoft.PowerShell.SecretManagement.SecretInformation]::new(
            $vaultSecretInfo.Name,
            $type,
            $VaultName,
            $hashtable
        )
    }
}