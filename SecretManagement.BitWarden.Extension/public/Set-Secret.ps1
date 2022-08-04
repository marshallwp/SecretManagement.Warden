function Set-Secret
{
    [CmdletBinding()]
    param (
        [string] $Name,
        [object] $Secret,
        [string] $VaultName,
        [hashtable] $AdditionalParameters
    )

	$eSecret = ConvertTo-BWEncoding $Secret
	if($AdditionalParameters.ContainsKey('organizationid')) {
		Invoke-BitwardenCLI edit item "$Name" $eSecret --organizationid $AdditionalParameters['organizationid']
	} else {
		Invoke-BitwardenCLI edit item "$Name" $eSecret
	}
}