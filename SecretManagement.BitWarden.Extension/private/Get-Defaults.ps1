# Imports default values from the config file.
function Get-Defaults {
    Param(
        # The AdditionalParameters hashtable provided by Microsoft.PowerShell.SecretManagement
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [hashtable]$AdditionalParameters,
        # Changes the directory to search for a config file in.  Mainly used in testing; the default should work when used in the module.
        [string]$BaseDirectory = "$PSScriptRoot\.."
    )
    $config = Import-LocalizedData -SupportedCommand New-TimeSpan -BaseDirectory $BaseDirectory -FileName "SecretManagement.Bitwarden.Extension.Config.psd1"

    $AdditionalParameters.EncodingOfSecrets ??= $config.EncodingOfSecrets
    $AdditionalParameters.ExportObjectsToSecureNotesAs ??= $config.ExportObjectsToSecureNotesAs
    $AdditionalParameters.MaximumObjectDepth ??= $config.MaximumObjectDepth
    $AdditionalParameters.ResyncCacheIfOlderThan ??= $config.ResyncCacheIfOlderThan

    return $AdditionalParameters
}