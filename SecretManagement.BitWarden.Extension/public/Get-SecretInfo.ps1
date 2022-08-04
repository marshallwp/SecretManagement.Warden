function Get-SecretInfo {
    [CmdletBinding()]
    param(
        [Alias('Name')][string] $Filter,
        [Alias('Vault')][string] $VaultName,
        [hashtable] $AdditionalParameters
    )

    [System.Collections.Generic.List[string]]$SearchParams = @("list","items")

    if ( $Filter ) {
        $SearchParams.Add( '--search' )
        $SearchParams.Add( $Name )
    }

    if ( $AdditionalParameters.ContainsKey('url')) {
        $SearchParams.Add( '--url' )
        $SearchParams.Add( $AdditionalParameters['url'] )
    }

    if ($AdditionalParameters.ContainsKey('folderName')) {
        $folder = Invoke-BitwardenCLI get folder "$($AdditionalParameters.folderName)"
        $SearchParams.Add( '--folderid' )
        $SearchParams.Add( $folder.id )
    }

    $vaultSecretInfos = Invoke-BitwardenCLI @SearchParams

    foreach ($vaultSecretInfo in $vaultSecretInfos) {
        if ($vaultSecretInfo.type -eq [BitwardenItemType]::Login) {
            $type = [Microsoft.PowerShell.SecretManagement.SecretType]::PSCredential
        }
        else { 
            $type = [Microsoft.PowerShell.SecretManagement.SecretType]::SecureString 
        }

        $hashtable = [ordered]@{}
        foreach($property in ($vaultSecretInfo | Select-Object -ExcludeProperty login,name,type)) {
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