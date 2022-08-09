function Unlock-SecretVault {
    [CmdletBinding()]
    param (
        [SecureString] $Password,
        [string] $VaultName = (Get-SecretVault | Where-Object {$_.IsDefault} | Select-Object -ExpandProperty Name),
        [hashtable] $AdditionalParameters
    )

    try {
        Invoke-BitwardenCLI unlock "$(ConvertFrom-SecureString $Password -AsPlainText)"
        Invoke-BitwardenCLI sync | Out-Null
    }
    catch {
        $ex = New-Object System.Security.Authentication.AuthenticationException "$VaultName Vault Unlock operation failed with error: $_"
        Write-Error -Exception $ex -ErrorId "BitwardenUnlockFailed" -Category AuthenticationError -ErrorAction Stop
    }

    Write-Verbose $env:BW_SESSION
}