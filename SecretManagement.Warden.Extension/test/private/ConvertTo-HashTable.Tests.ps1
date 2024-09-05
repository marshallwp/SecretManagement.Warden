BeforeAll {
    . (Join-Path $PSScriptRoot ".." ".." "private" "ConvertTo-Hashtable.ps1")
}

Describe "ConvertTo-Hashtable" {
    Context "Output from <Name>" -ForEach @(
        @{Name="Null"; Case=$null},
        @{Name="Null Array"; Case=@($null)}
    ) {
        It "Piped Input Returns `$null" {
            $Case | ConvertTo-HashTable | Should -BeNullOrEmpty
        }
        It "Parameter Input Returns `$null" {
            ConvertTo-HashTable $Case | Should -BeNullOrEmpty
        }
    }

    Context "Input by <IptWay>" -ForEach @(
        @{IptWay="Pipe";      Cmd=[ScriptBlock]{$Case | ConvertTo-HashTable}},
        @{IptWay="Parameter"; Cmd=[ScriptBlock]{ConvertTo-HashTable $Case}}
    ) {
        Context "Output from <Name>" -ForEach @(
            @{Name="Null"; Case=$null},
            @{Name="Null Array"; Case=@($null)}
        ) {
            It "Output is `$null" {
                .$Cmd | Should -BeNullOrEmpty
            }
        }

        Context "Output from <Name>" -ForEach @(
            @{Name="Simple Object"; Case=[PSCustomObject]@{key = "value"}},
            @{Name="Nested Object"; Case=[PSCustomObject]@{key1 = "val1"; nest1 = [PSCustomObject]@{nestKey = 1}}},
            @{Name="Multiple Objects"; Case=@([PSCustomObject]@{key1 = "val1"; nestArray = @([PSCustomObject]@{nestKey = 1},[PSCustomObject]@{nestKey = 2})})}
        ) {
            It "Output Is Not Null" {
                .$Cmd | Should -Not -BeNullOrEmpty
            }
            It "Outputs Unordered Hashtable" {
                (.$Cmd).GetType().Name -eq "Hashtable"
            }

            It "Conversion Preserves Keys and Values" {
                $Example = .$Cmd
                Compare-Object -ReferenceObject $Case -DifferenceObject ([PSCustomObject]$Example) |
                    Should -BeNullOrEmpty
            }

            It "Output Object Count == Input Object Count" {
                $IptCnt = ($Case | Measure-Object).Count
                (.$Cmd | Measure-Object).Count | Should -Be $IptCnt
            }
        }
    }
}
