<#
.SYNOPSIS
    Sync the Bitwarden Vault but minimize the number of calls needed to do so.
.DESCRIPTION
    By locally caching the LastSyncedTime we can significanly reduce the number of `Invoke-BitwardenCLI sync --last` calls we need to make.  As these are very slow calls, caching the results can improve performance dramatically.
.PARAMETER ResyncCacheIfOlderThan
    TimeSpan indicating how long before the bitwarden cache is considered expired and a new sync needs to be run.
.PARAMETER Force
    If provided, the bitwarden cach will be synced regardless of how old it is.
#>
function Sync-BitwardenVault {
    Param(
        [TimeSpan]$ResyncCacheIfOlderThan,
        [switch]$Force
    )

    # Stores the cache file in a subdirectory of the SecretManagement vault registry location:
    # https://github.com/PowerShell/SecretManagement/#extension-vault-registry-file-location
    $CacheLocation = $IsWindows ? "$env:LocalAppData\Microsoft\PowerShell\secretmanagement\bitwarden-ext\LastSyncedTime.txt" : "$HOME/.secretmanagement/bitwarden-ext/LastSyncedTime.txt"

    # Get Last Synced time from file or the Bitwarden CLI (much slower)
    if(Test-Path -Path $CacheLocation -PathType Leaf) {
        $LastSyncedTime = Get-Content -Path $CacheLocation | Get-Date
    }
    else {
        New-Item $CacheLocation -Force  # Create the missing file.
        $LastSyncedTime = Invoke-BitwardenCLI sync --last | Get-Date
    }

    # Sync Cache if $Force or if time since $LastSyncedTime is greater than $ResyncCacheIfOlderThan time back.
    if($Force -or (New-TimeSpan -Start $LastSyncedTime).TotalSeconds -gt $ResyncCacheIfOlderThan.TotalSeconds) {
        # If so, sync the vault.
        Invoke-BitwardenCLI sync --quiet
        # And update the cache.
        Get-Date -Format "o" | Out-File -FilePath $CacheLocation -NoNewline
    }
}