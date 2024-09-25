BeforeAll {
    Import-Module -Name Microsoft.PowerShell.SecretManagement

    $BasePath = Join-Path $PSScriptRoot ".." ".."
    . (Join-Path $BasePath "public" "Get-SecretInfo.ps1")
    . (Join-Path $BasePath "private" "Sync-BitwardenVault.ps1")
    . (Join-Path $BasePath "private" "Merge-Defaults.ps1")
    . (Join-Path $BasePath "private" "Invoke-BitwardenCLI")
    . (Join-Path $BasePath "classes" "BitwardenEnum.ps1")

    Mock Sync-BitwardenVault { }

    Import-Module -Name Microsoft.PowerShell.SecretManagement
}

Describe "Get-SecretInfo" {
    Context "Regular Secure Note" {
        BeforeAll {
            $mock = Import-CliXml -Path (Join-Path $PSScriptRoot "mock" "old-secrets" "secure-notes" "mock-securenote.xml")
            Mock Invoke-BitwardenCLI { return $mock }
            $Result = Get-SecretInfo -Filter "My Test Note" -AdditionalParameters @{}
        }

        It "Returns SecretInformation" {
            $Result | Should -BeOfType Microsoft.PowerShell.SecretManagement.SecretInformation
        }
        It "Validate SecretInformation: <Name> is <Value>" -ForEach @(
            @{Name="name";Value="f6c97ce7-953e-4c06-a12e-45e1b16be4df"},
            @{Name="type";Value=[Microsoft.PowerShell.SecretManagement.SecretType]::SecureString}
        ) {
            $Result.$Name | Should -Be $Value
        }

        It "Validate Metadata" {
            $Result.Metadata | Should -Not -BeNullOrEmpty
        }
    }

    Context "Object Stored as JSON in Secure Note" {
        BeforeAll {
            $mock = Import-CliXml -Path (Join-Path $PSScriptRoot "mock" "old-secrets" "secure-notes" "mock-obj-json.xml")
            Mock Invoke-BitwardenCLI { return $mock }
            $Result = Get-SecretInfo -Filter "JSON-Test-Obj" -AdditionalParameters @{}
        }
        It "Returns SecretInformation" {
            $Result | Should -BeOfType Microsoft.PowerShell.SecretManagement.SecretInformation
        }
        It "Validate SecretInformation: <Name> is <Value>" -ForEach @(
            @{Name="name";Value="361a554c-d79e-4e79-bf2e-aff656528ec3"},
            @{Name="type";Value=[Microsoft.PowerShell.SecretManagement.SecretType]::Hashtable}
        ) {
            $Result.$Name | Should -Be $Value
        }
        It "Metadata Exists" {
            $Result.Metadata | Should -Not -BeNullOrEmpty
        }
        It "Item Name in Metadata" {
            $Result.Metadata.name | Should -Be $mock.name
        }
    }

    Context "Object Stored as CliXml in Secure Note" {
        BeforeAll {
            $mock = Import-CliXml -Path (Join-Path $PSScriptRoot "mock" "old-secrets" "secure-notes" "mock-obj-xml.xml")
            Mock Invoke-BitwardenCLI { return $mock }
            $Result = Get-SecretInfo -Filter "XML-Test-Obj" -AdditionalParameters @{}
        }
        It "Returns SecretInformation" {
            $Result | Should -BeOfType Microsoft.PowerShell.SecretManagement.SecretInformation
        }
        It "Validate SecretInformation: <Name> is <Value>" -ForEach @(
            @{Name="name";Value="b5c3eebb-871e-42c3-9e88-0b26711b9a96"},
            @{Name="type";Value=[Microsoft.PowerShell.SecretManagement.SecretType]::Hashtable}
        ) {
            $Result.$Name | Should -Be $Value
        }
        It "Metadata Exists" {
            $Result.Metadata | Should -Not -BeNullOrEmpty
        }
        It "Item Name in Metadata" {
            $Result.Metadata.name | Should -Be $mock.name
        }
    }
}
