<#
.SYNOPSIS
    Merges default values from the config file into $AdditionalProperties.
.PARAMETER AdditionalParameters
    The AdditionalParameters hashtable provided by Microsoft.PowerShell.SecretManagement
.PARAMETER BaseDirectory
    Changes the directory to search for a config file in.  Mainly used in testing; the default should work when used in the module.
.EXAMPLE
    $AdditionalParameters = Merge-Defaults $AdditionalParameters
    Merges default config values into the $AdditionalParameters hashtable, favoring existing values over defaults.
#>
function Merge-Defaults {
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [hashtable]$AdditionalParameters,

        [string]$BaseDirectory = "$PSScriptRoot\.."
    )
    $config = Import-LocalizedData -SupportedCommand New-TimeSpan -BaseDirectory $BaseDirectory -FileName "SecretManagement.Bitwarden.Extension.Config.psd1"

    foreach( $property in $config.Keys ) {
        $AdditionalParameters.$property ??= $config.$property
    }

    return $AdditionalParameters
}
