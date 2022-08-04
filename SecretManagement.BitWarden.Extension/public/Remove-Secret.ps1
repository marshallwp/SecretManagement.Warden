function Remove-Secret {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('ID')][string] $Name,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $VaultName,
        [Parameter(ValueFromPipelineByPropertyName)]
        [hashtable] $AdditionalParameters
    )

    [System.Collections.Generic.List[string]]$SearchParams = @("delete","item","$Name")

    if ( $AdditionalParameters.ContainsKey('organizationid')) {
        $SearchParams.Add( '--organizationid' )
        $SearchParams.Add( $AdditionalParameters['organizationid'] )
    }

    Invoke-BitwardenCLI @SearchParams
}