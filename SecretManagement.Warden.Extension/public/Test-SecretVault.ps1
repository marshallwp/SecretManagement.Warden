<#
.SYNOPSIS
    Tests for problems with a SecretVault and performs some resolutions.
.DESCRIPTION
    Tests to see if you are logged in and the vault is unlocked.  Will also force a cache synchronization, which can fix missing credential issues.
.NOTES
    Per SecretManagement documentation, "The Test-SecretVault cmdlet should write all errors that occur during the test. But only a single true/false boolean should be written the the output pipeline indicating success."
#>
function Test-SecretVault {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $VaultName,
        [Parameter(ValueFromPipelineByPropertyName)]
        [hashtable] $AdditionalParameters
    )
    # Enable Verbose Mode inside this script if passed from the wrapper.
    if($AdditionalParameters.ContainsKey('Verbose') -and ($AdditionalParameters['Verbose'] -eq $true)) {$script:VerbosePreference = 'Continue'}

    if(!(Invoke-BitwardenCLI login --check --quiet)) {
        Write-Error "You are not logged into $VaultName.  Set API Key Environmental Variables per https://bitwarden.com/help/cli/#using-an-api-key or (if running interactively) run 'bw login'."
        return $false
    }
    #* Bitwarden CLI has a bug in the check unlocked code that makes it nearly always report that the vault is locked.  Attempting to list folders is the workaround.
    # https://github.com/bitwarden/clients/issues/2729
    elseif(!(Invoke-BitwardenCLI list folders --quiet)) {
        Write-Error "The $VaultName vault is locked."
        return $false
    }
    else {
        Sync-BitwardenVault -Force
        return $true
    }
}
