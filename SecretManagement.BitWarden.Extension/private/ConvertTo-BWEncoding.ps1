<#
.SYNOPSIS
 Base64 encodes an object for Bitwarden CLI

.DESCRIPTION
 Base64 encodes an object for Bitwarden CLI
#>
function ConvertTo-BWEncoding {
    [CmdletBinding()]
    param(
        [Parameter( Mandatory, Position = 0, ValueFromPipeline )]
        [object]
        $InputObject
    )

    process {
        if ( $InputObject -isnot [string] ) {
            try {
                $InputObject | ConvertFrom-Json > $null
                Write-Verbose 'Object is already a JSON string'
            } catch {
                Write-Verbose 'Converting object to JSON'
                $InputObject = ConvertTo-Json -InputObject $InputObject -Compress
            }
        }

        try {
            [convert]::FromBase64String( $InputObject ) > $null
            Write-Verbose 'Object is already Base64 encoded'
            return $InputObject
        } catch {
            Write-Verbose 'Converting JSON to Base64 encoding'
            return [convert]::ToBase64String( [System.Text.Encoding]::UTF8.GetBytes( $InputObject ) )
        }
    }
}
