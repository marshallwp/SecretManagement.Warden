function Test-SecretVault {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $VaultName,
        [Parameter(ValueFromPipelineByPropertyName)]
        [hashtable] $AdditionalParameters
    )

    if(!(Invoke-BitwardenCLI login --check --quiet)) {
        Write-Error "You are not logged into $VaultName vault."
        return $false
    }
    #* Bitwarden CLI has a bug in the check unlocked code that makes it nearly always report that the vault is locked.  Attempting to list folders is the workaround.
    # https://github.com/bitwarden/clients/issues/2729
    elseif(!(Invoke-BitwardenCLI list folders --quiet)) {
        Write-Error "The $VaultName vault is locked."
        return $false
    }
    else {
        Invoke-BitwardenCLI sync | Out-Null
        return $true
    }
}