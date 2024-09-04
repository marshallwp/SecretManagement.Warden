BeforeAll {
    . (Join-Path $PSScriptRoot ".." ".." "private" "Merge-Defaults.ps1")
}

Describe "Merge-Defaults" {
    BeforeAll {
        $Defaults = Merge-Defaults @{}
    }

    It "Loads Defaults" {
        $Defaults | Should -Not -BeNullOrEmpty
    }

    It "Adds New Properties" {
        $example = Merge-Defaults @{test="value"}
        $example.test | Should -BeExactly "value"
    }

    It "Overrides Default Values" {
        $expected = New-TimeSpan -Hours 1
        $example = Merge-Defaults @{ResyncCacheIfOlderThan = $expected}
        $example.ResyncCacheIfOlderThan | Should -Be $expected
    }

    Context "Validate Defaults" {

        It "ExportObjectsToSecureNotesAs is JSON or CliXml" {
            $Defaults.ExportObjectsToSecureNotesAs | Should -BeIn ("JSON","CliXml")
        }
        It "MaximumObjectDepth is > 0" {
            $Defaults.MaximumObjectDepth | Should -BeGreaterThan 0
        }
        It "ResyncCacheIfOlderThan is TimeSpan" {
            $Defaults.ResyncCacheIfOlderThan | Should -BeOfType TimeSpan
        }
    }
}
