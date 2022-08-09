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

    $ResyncCacheIfOlderThan = if($AdditionalParameters.ResyncCacheIfOlderThan) {$AdditionalParameters.ResyncCacheIfOlderThan} else {New-TimeSpan -Hours 3}
    if((New-TimeSpan -Start (Invoke-BitwardenCLI sync --last | Get-Date)).TotalSeconds -gt $ResyncCacheIfOlderThan.TotalSeconds) {
        Invoke-BitwardenCLI sync --quiet | Out-Null
    }

    [System.Collections.Generic.List[string]]$CmdParams = @("delete","item")
    $CmdParams.Add($Name)

    if ( $AdditionalParameters.ContainsKey('organizationid')) {
        $CmdParams.Add( '--organizationid' )
        $CmdParams.Add( $AdditionalParameters['organizationid'] )
    }

    Invoke-BitwardenCLI @CmdParams
}