function Unregister-SecretVault
{
    [CmdletBinding()]
    param (
        [string] $VaultName,
        [hashtable] $AdditionalParameters
    )

    # Removes the bitwarden-ext directory and all contents from the computer.
    $BitwardenExtDir = $IsWindows ? "$env:LocalAppData\Microsoft\PowerShell\secretmanagement\bitwarden-ext" : "$HOME/.secretmanagement/bitwarden-ext"
    if(Test-Path -Path $BitwardenExtDir -PathType Container) {
        Remove-Item -Path $BitwardenExtDir -Recurse
    }
}
