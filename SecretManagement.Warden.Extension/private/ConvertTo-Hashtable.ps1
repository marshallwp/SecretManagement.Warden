<#
.SYNOPSIS
    Converts a PSCustomObject to a HashTable.
.NOTES
    In PowerShell 7.3+, "ConvertFrom-Json -AsHashtable" outputs an [OrderedHashtable] object. Unfortunately, Get-Secret does not allow you to return an OrderedHashtable, so this function is used to create a regular, unordered variant.
.EXAMPLE
    $json | ConvertFrom-Json | ConvertTo-HashTable
    Parses JSON string and outputs a HashTable.
#>
function ConvertTo-HashTable
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
                foreach ($object in $InputObject) { ConvertTo-HashTable $object }
            )

            Write-Output $collection -NoEnumerate
        }
        elseif ($InputObject -is [PSObject] -and $InputObject -isnot [SecureString])
        {
            $hash = @{}

            foreach ($property in $InputObject.PSObject.Properties)
            {
                $hash[$property.Name] = ConvertTo-HashTable $property.Value
            }

            $hash
        }
        else
        {
            $InputObject
        }
    }
}
