BeforeAll {
    . (Join-Path $PSScriptRoot ".." ".." "private" "Test-KeysInHashtable.ps1")
}

Describe "Test-KeysInHashtable" {
    BeforeAll {
        $TestCase = @{UserName="TestUser"; Password="SuperSecret"}
    }

    It "Returns <Expected> if <Name>" -ForEach @(
        @{Name="Single Key Exists"; Case=@('UserName'); Expected=$true},
        @{Name="Single Key Missing"; Case=@('Nonexistent'); Expected=$false},
        @{Name="Matches Any Key"; Case=@('UserName','Nonexistent'); Expected=$true},
        @{Name="Does Not Match Any Key"; Case=@('BadKey','Nonexistent'); Expected=$false}
    ) {
        Test-KeysInHashtable -Hashtable $TestCase -Keys $Case | Should -Be $Expected
    }

    Context "-MatchAll Mode" {
        It "Returns <Expected> if <Name>" -ForEach @(
            @{Name="All Keys Exist"; Case=@('UserName','Password'); Expected=$true},
            @{Name="One Key Missing"; Case=@('UserName','Nonexistent'); Expected=$false}
            @{Name="All Keys Missing"; Case=@('BadKey','Nonexistent'); Expected=$false}
        ) {
            Test-KeysInHashtable -Hashtable $TestCase -Keys @('UserName','Password') -MatchAll |
                Should -BeTrue
        }
    }
}
