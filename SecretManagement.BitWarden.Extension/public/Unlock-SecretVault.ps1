function Unlock-SecretVault {
    [CmdletBinding()]
    param (
        [SecureString] $Password,
        [string] $VaultName,
        [hashtable] $AdditionalParameters
    )
    # Enable Verbose Mode inside this script if passed from the wrapper.
    if($AdditionalParameters.ContainsKey('Verbose') -and ($AdditionalParameters['Verbose'] -eq $true)) {$script:VerbosePreference = 'Continue'}

    try {
        Invoke-BitwardenCLI unlock "$(ConvertFrom-SecureString $Password -AsPlainText)"
        Sync-BitwardenVault -Force
    }
    catch {
        $ex = New-Object System.Security.Authentication.AuthenticationException "$VaultName Vault Unlock operation failed with error: $_"
        Write-Error -Exception $ex -ErrorId "BitwardenUnlockFailed" -Category AuthenticationError -ErrorAction Stop
    }

    Write-Verbose $env:BW_SESSION
}