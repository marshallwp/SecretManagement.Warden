<#
.SYNOPSIS
	Gets a singular secret and metadata.
.DESCRIPTION
	Used for things like Set-Secret and Set-SecretInfo.  The way bw.exe works, you can't just edit a field, you must pull the full secret, edit what you want, then send that back as the new version of the secret.
#>
function Get-FullSecret {
    [CmdletBinding()]
    param(
        [Alias('ID')][string] $Name,
        [hashtable] $AdditionalParameters = @{}
    )

    # Enable Verbose Mode inside this script if passed from the wrapper.
    if($AdditionalParameters.ContainsKey('Verbose') -and ($AdditionalParameters['Verbose'] -eq $true)) {$script:VerbosePreference = 'Continue'}
    $AdditionalParameters = Merge-Defaults $AdditionalParameters
    Sync-BitwardenVault $AdditionalParameters.ResyncCacheIfOlderThan

    [System.Collections.Generic.List[string]]$CmdParams = @("get","item")
    $CmdParams.Add($Name)

    if ( $AdditionalParameters.ContainsKey('organizationid') ) {
        $CmdParams.Add('--organizationid')
        $CmdParams.Add($AdditionalParameters['organizationid'])
    }

    $CmdParams.Add('--raw')
    try {
        $Result = Invoke-BitwardenCLI @CmdParams
    }
    # Ignore just errors about not finding anything.
    catch [System.Management.Automation.ItemNotFoundException],[System.DirectoryServices.AccountManagement.NoMatchingPrincipalException] {
        return $null
    }

    return $Result | ConvertFrom-Json
}
