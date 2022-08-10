function Unregister-SecretVault
{
    [CmdletBinding()]
    param (
        [string] $VaultName,
        [hashtable] $AdditionalParameters
    )

    # Removes the cache file from the system.
    $CacheLocation = $IsWindows ? "$env:LocalAppData\Microsoft\PowerShell\secretmanagement\bitwarden-ext\LastSyncedTime.txt" : "$HOME/.secretmanagement/bitwarden-ext/LastSyncedTime.txt"
    Remove-Item -Path $CacheLocation | Out-Null
}