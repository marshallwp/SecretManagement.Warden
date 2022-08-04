#* This is for reference.  These commands are not used.

<#
.SYNOPSIS
 Retrieve a credential from the Bitwarden CLI

.DESCRIPTION
 Retrieve a credential from the Bitwarden CLI
#>
function Get-BWCredential {

    param(
        [Parameter( Position = 1)]
        [string]
        $UserName,
        [string]
        $Url,
        [ValidateSet( 'Choose', 'Error' )]
        [string]
        $MultipleAction = 'Error'
    )

    [System.Collections.Generic.List[string]]$SearchParams = 'list', 'items'

    if ( $UserName ) {
        $SearchParams.Add( '--search' )
        $SearchParams.Add( $UserName )
    }

    if ( $Url ) {
        $SearchParams.Add( '--url' )
        $SearchParams.Add( $Url )
    }

    $Result = Invoke-BitwardenCLI @SearchParams | Where-Object { $_.login.credential }

    if ( -not $Result ) {
        Write-Error 'No results returned'
        return
    }

    if ( $Result.Count -gt 1 -and $MultipleAction -eq 'Error' ) {
        Write-Error 'Multiple entries returned'
        return
    }

    if ( $Result.Count -gt 1 ) {
        return $Result | Select-BWCredential
    }

    return $Result.login.credential

}

<#
.SYNOPSIS
 Select a credential from those returned from the Bitwarden CLI

.DESCRIPTION
 Select a credential from those returned from the Bitwarden CLI
#>
function Select-BWCredential {
    param(
        [Parameter( Mandatory = $true, ValueFromPipeline = $true )]
        [pscustomobject[]]
        $BitwardenItems
    )

    begin {
        [System.Collections.ArrayList]$LoginItems = @()
    }

    process {
        $BitwardenItems.Where({ $_.login }) | ForEach-Object { $LoginItems.Add($_) > $null }
    }

    end {
        if ( $LoginItems.Count -eq 0 ) {
            Write-Warning 'No login found!'
            return
        }

        if ( $LoginItems.Count -eq 1 ) {
            return $LoginItems.login.Credential
        }

        $SelectedItem = $LoginItems |
            Select-Object Id, Name, @{N='UserName';E={$_.login.username}}, @{N='PrimaryURI';E={$_.login.uris[0].uri}} |
            Out-GridView -Title 'Choose Login' -OutputMode Single

        return $LoginItems.Where({ $_.Id -eq $SelectedItem.Id }).login.Credential
    }
}