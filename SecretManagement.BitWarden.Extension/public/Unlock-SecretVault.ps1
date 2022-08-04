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
        $Msg = "$VaultName Vault Unlock operation failed with error: $_"

        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.Security.Authentication.AuthenticationException]::new($Msg),
            "BitwardenUnlockFailed",
            [System.Management.Automation.ErrorCategory]::AuthenticationError,
            $null)
        Write-Error -ErrorRecord $errorRecord
    }

    Write-Verbose $env:BW_SESSION
}