<#
.SYNOPSIS
    Get the location of the last resynced time cache.
.EXAMPLE
    PS> Get-CacheLocation
.NOTES
    This only exists as a separate function from Sync-BitwardenVAult so it can be Mocked during Pester Testing.  Specifically, we can Mock the output to let us use a Pester TestDrive for the cache file.
#>
function Get-CacheLocation {
    if($IsWindows) {"$env:LocalAppData\Microsoft\PowerShell\secretmanagement\warden-ext\LastSyncedTime.txt"}
    else {"$HOME/.secretmanagement/warden-ext/LastSyncedTime.txt"}
}
