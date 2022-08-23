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
        Sync-BitwardenVault
    }
    catch {
        $ex = New-Object System.Security.Authentication.AuthenticationException "$_"
        throw $ex   # In Unlock-SecretVault, throw produces nicer errors than Write-Error.
    }

    Write-Verbose $env:BW_SESSION
}
