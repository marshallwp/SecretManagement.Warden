<#
.SYNOPSIS
    Converts a PSCustomObject to a Hashtable.
.NOTES
    Microsoft.PowerShell.SecretManagement only supports the following data types: byte[], string, SecureString, PSCredential, and Hashtable.
    See: https://github.com/PowerShell/SecretManagement/blob/main/README.md
.EXAMPLE
    $json | ConvertFrom-Json | ConvertTo-Hashtable
    Parses JSON string and outputs a HashTable.
.EXAMPLE
    ConvertTo-Hashtable ($json | ConvertFrom-Json)
    Parses JSON string and outputs a HashTable.
#>
function ConvertTo-Hashtable
{
    param (
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    process
    {
        if ($null -eq $InputObject) {
            return $null
        }
        elseif ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string] `
            -and $InputObject -isnot [hashtable] -and $InputObject -isnot [System.Collections.Specialized.OrderedDictionary])
        {
            $collection = @(
                foreach ($object in $InputObject) { ConvertTo-Hashtable $object }
            )

            Write-Output $collection -NoEnumerate
        }
        elseif ($InputObject -is [PSObject] -and $InputObject -isnot [SecureString])
        {
            $hash = @{}

            foreach ($property in $InputObject.PSObject.Properties)
            {
                $hash[$property.Name] = ConvertTo-Hashtable $property.Value
            }

            $hash
        }
        else
        {
            $InputObject
        }
    }
}
