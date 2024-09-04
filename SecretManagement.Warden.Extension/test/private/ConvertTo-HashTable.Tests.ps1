BeforeAll {
    . (Join-Path $PSScriptRoot ".." ".." "private" "ConvertTo-Hashtable.ps1")
}

Describe "ConvertTo-Hashtable" {
    Context "Output from <Name>" -ForEach @(
        @{Name="Simple Object"; Case=[PSCustomObject]@{key = "value"}},
        @{Name="Nested Object"; Case=[PSCustomObject]@{key1 = "val1"; nest1 = [PSCustomObject]@{nestKey = 1}}}
    ) {
        It "Output Is Not Null" {
            $Case | ConvertTo-HashTable | Should -Not -BeNullOrEmpty
        }

        It "Outputs Unordered Hashtable" {
            ($Case | ConvertTo-Hashtable).GetType().Name -eq "Hashtable"
        }

        It "Conversion Preserves Keys and Values" {
            $Example = $Case | ConvertTo-Hashtable
            Compare-Object -ReferenceObject $Case -DifferenceObject ([PSCustomObject]$Example) |
                Should -BeNullOrEmpty
        }
    }
}
