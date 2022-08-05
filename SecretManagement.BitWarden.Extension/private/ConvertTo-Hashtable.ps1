<#
.SYNOPSIS
    Converts a PSCustomObject to a HashTable.
.NOTES
    This is mainly intended to help workaround how the -AsHashTable parameter in ConvertFrom-JSON was added in PowerShell 6.0.
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
        if ($null -eq $InputObject) { return $null }

        if ($InputObject -is [hashtable] -or $InputObject.GetType().Name -eq 'OrderedDictionary') { return $InputObject }

        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string])
        {
            $collection = @(
                foreach ($object in $InputObject) { ConvertTo-HashTable $object }
            )

            # Write-Output $collection -NoEnumerate
            Write-Output $collection
        }
        elseif ($InputObject -is [psobject])
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