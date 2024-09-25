BeforeAll {
    $BasePath = Join-Path $PSScriptRoot ".." ".."
    . (Join-Path $BasePath "public" "Get-Secret.ps1")
    . (Join-Path $BasePath "private" "ConvertTo-BWEncoding.ps1")
    . (Join-Path $BasePath "private" "ConvertTo-Hashtable.ps1")
    . (Join-Path $BasePath "private" "Merge-Defaults.ps1")
    . (Join-Path $BasePath "private" "Sync-BitwardenVault.ps1")
    . (Join-Path $BasePath "private" "Invoke-BitwardenCLI.ps1")
    . (Join-Path $BasePath "classes" "BitwardenEnum.ps1")
    . (Join-Path $BasePath "classes" "BitwardenPasswordHistory.ps1")

    Mock Sync-BitwardenVault { }
}

Describe "Get-Secret" {
    It "Returns '`$null' for non-existent secret." {
        Mock Invoke-BitwardenCLI {
            $ex = New-Object System.Management.Automation.ItemNotFoundException "Not found."
            Write-Error $ex -Category ObjectNotFound -ErrorAction Stop
        }
        Get-Secret -Name '00000000-0000-0000-0000-000000000000' -AdditionalParameters @{} | Should -BeNullOrEmpty
    }

    # Loops through all non-secure note secret returns and validates that
    # the values of the item type field match the values in the Get-Secret return.
    BeforeDiscovery {
        $mocks = Get-ChildItem (Join-Path $PSScriptRoot "mock" "old-secrets") -Filter "*.xml" |
            Select-Object @{Name="MockedType";Expression={($_.BaseName -split '-')[-1]}},
                @{Name="Mock";Expression={Import-Clixml $_.FullName}} |
            Select-Object *,
                @{Name="Expected";Expression={($_.Mock.$($_.MockedType) | ConvertTo-Hashtable).GetEnumerator()}},
                @{Name="ID";Expression={$_.Mock.id}}
    }
    Context "Returns <_.MockedType>" -ForEach $mocks {
        BeforeAll {
            $mock = $_
            Mock Invoke-BitwardenCLI { return $mock.Mock }
            $Result = Get-Secret -Name $mock.ID -AdditionalParameters @{}
        }
        It "<_.Key> == <_.Value>" -ForEach $_.Expected {
            $Result.($_.Key) | Should -BeExactly $_.Value
        }
    }

    Context "Returns SecureNote" {
        BeforeAll {
            $mock = Import-Clixml -Path (Join-Path $PSScriptRoot "mock" "old-secrets" "secure-notes" "mock-securenote.xml")
            Mock Invoke-BitwardenCLI { return $mock }
            $Result = Get-Secret -Name $mock.id -AdditionalParameters @{}
        }
        It "Only the note is returned" {
            $Result | Should -BeOfType string
        }
        It "The value of the note is accurate." {
            $Result | Should -BeExactly $mock.notes
        }
    }

    Context "Returns Object Stored as JSON SecureNote" {
        BeforeAll {
            $mock = Import-Clixml -Path (Join-Path $PSScriptRoot "mock" "old-secrets" "secure-notes" "mock-obj-json.xml")
            Mock Invoke-BitwardenCLI { return $mock }
            $Result = Get-Secret -Name $mock.ID -AdditionalParameters @{}
        }
        It "Output is HashTable" {
            $Result -is [Hashtable] | Should -BeTrue
        }
        It "Outputs the Expected Object" {
            # Outputs end up as OrderedHashtables with different sortings.
            # Sort-Object does nothing to these.
            # To workaround this, we convert them to a PSCustomObject before comparison.
            $Expected = Import-Clixml -Path (Join-Path $PSScriptRoot "mock" "old-secrets" "secure-notes" "expected-obj-json.xml") |
                Select-Object *
            $ResultComp = $Result | Select-Object *
            Compare-Object -ReferenceObject $Expected -DifferenceObject $ResultComp | Should -BeNullOrEmpty
        }
    }

    Context "Returns Object Stored as CliXml SecureNote" {
        BeforeAll {
            $mock = Import-Clixml -Path (Join-Path $PSScriptRoot "mock" "old-secrets" "secure-notes" "mock-obj-xml.xml")
            Mock Invoke-BitwardenCLI { return $mock }
            $Result = Get-Secret -Name $mock.ID -AdditionalParameters @{}
        }
        It "Output is PSCustomObject" {
            $Result -is [PSCustomObject] | Should -BeTrue
        }
        It "Output is the Expected Object" {
            $Expected = Import-Clixml -Path (Join-Path $PSScriptRoot "mock" "old-secrets" "secure-notes" "expected-obj-xml.xml")
            Compare-Object -ReferenceObject $Expected -DifferenceObject $Result | Should -BeNullOrEmpty
        }
    }

    Context "Throw Errors On" {
        It "Invalid PowerShellObjectRepresentation value" {
            $mock = Import-Clixml -Path (Join-Path $PSScriptRoot "mock" "old-secrets" "secure-notes" "mock-obj-invalid.xml")
            Mock Invoke-BitwardenCLI { return $mock }
            {Get-Secret -Name $mock.id -AdditionalParameters @{}} | Should -Throw "*is not a supported means of representing a PowerShell Object.*"
        }
        It "Invalid BitwardenItemType" {
            $mock = Import-Clixml -Path (Join-Path $PSScriptRoot "mock" "old-secrets" "mock-undefined.xml")
            Mock Invoke-BitwardenCLI { return $mock }
            {Get-Secret -Name $mock.id -AdditionalParameters @{}} | Should -Throw "The * is not supported."
        }
    }

}
