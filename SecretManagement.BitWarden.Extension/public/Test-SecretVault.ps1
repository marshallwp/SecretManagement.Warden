function Test-SecretVault {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $VaultName,
        [Parameter(ValueFromPipelineByPropertyName)]
        [hashtable] $AdditionalParameters
    )

    if((Invoke-BitwardenCLI login --check --quiet) -and (Invoke-BitwardenCLI unlock --check --quiet)) {
        return $true
    }
    else {
        Write-Error "The $VaultName vault is currently $((Invoke-BitwardenCLI status).status)"
        return $false
    }
}