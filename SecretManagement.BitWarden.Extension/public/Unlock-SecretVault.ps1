function Unlock-SecretVault {
    [CmdletBinding()]
    param (
        [SecureString] $Password,
        [string] $VaultName,
        [hashtable] $AdditionalParameters
    )

    try {
        Invoke-BitwardenCLI unlock "$(ConvertFrom-SecureString $Password -AsPlainText)"
    }
    catch {
        $ex = New-Object System.Security.Authentication.AuthenticationException "$VaultName Vault Unlock operation failed with error: $_"
        Write-Error -Exception $ex -ErrorId "BitwardenUnlockFailed" -Category AuthenticationError -ErrorAction Stop
    }

    Write-Verbose $env:BW_SESSION
}