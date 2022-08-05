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
        [Alias('Vault')][string] $VaultName,
        [hashtable] $AdditionalParameters
    )

    [System.Collections.Generic.List[string]]$CmdParams = @("get","item","$Name")

    if ( $AdditionalParameters.ContainsKey('organizationid')) {
        $CmdParams.Add( '--organizationid' )
        $CmdParams.Add( $AdditionalParameters['organizationid'] )
    }

    $CmdParams.Add('--raw')
    $Result = Invoke-BitwardenCLI @CmdParams | ConvertFrom-Json

	if ( ! $Result ) {
        $ex = New-Object System.Management.Automation.ItemNotFoundException "Revise your search filter so it matches a secret in the vault."
        Write-Error -Exception $ex -Category ObjectNotFound -CategoryActivity 'Invoke-BitwardenCLI @CmdParams' -CategoryTargetName '$Result' -CategoryTargetType 'PSCustomObject' -ErrorAction Stop
    } elseif ( $Result.Count -gt 1 ) {
        throw 'Multiple entries returned'
    } else {
		return $Result
	}
}