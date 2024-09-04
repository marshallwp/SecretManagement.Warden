function Unregister-SecretVault
{
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "VaultName", Justification = "Function must accept this parameter to be valid.")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "AdditionalParameters", Justification = "Function must accept this parameter to be valid.")]
    param (
        [string] $VaultName,
        [hashtable] $AdditionalParameters
    )

    # Removes the bitwarden-ext directory and all contents from the computer.
    $BitwardenExtDir = Get-CacheLocation | Split-Path -Parent
    if(Test-Path -Path $BitwardenExtDir -PathType Container) {
        Remove-Item -Path $BitwardenExtDir -Recurse
    }
}
