<#
.SYNOPSIS
    Get the file path of the last resynced time cache.
.DESCRIPTION
    Return the file path of the LastSyncedTime.txt cache file. Location will vary based on whether it is running on a Windows or non-Windows platform.
.EXAMPLE
    PS> Get-CacheLocation
.NOTES
    This function exists so it can be Mocked during Pester Testing.  Specifically, we can Mock the output to let us use a Pester TestDrive for the cache file.

    The cache file is in a subdirectory of the SecretManagement vault registry location:
    https://github.com/PowerShell/SecretManagement/#extension-vault-registry-file-location
#>
function Get-CacheLocation {
    if($IsWindows) {"$env:LocalAppData\Microsoft\PowerShell\secretmanagement\warden-ext\LastSyncedTime.txt"}
    else {"$HOME/.secretmanagement/warden-ext/LastSyncedTime.txt"}
}
