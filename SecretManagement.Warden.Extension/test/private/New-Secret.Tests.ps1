BeforeAll {
    $BasePath = Join-Path $PSScriptRoot ".." ".."
    . (Join-Path $BasePath "private" "New-Secret.ps1")
    . (Join-Path $BasePath "private" "Invoke-BitwardenCLI.ps1")
    . (Join-Path $BasePath "classes" "BitwardenEnum.ps1")

    # Mock the different templates
    Mock Invoke-BitwardenCLI -ParameterFilter {$args[0] -eq "get" -and $args[1] -eq "template" -and $args[2] -eq "item"} `
        -MockWith { return Import-Clixml (Join-Path $PSScriptRoot "item-templates" "item.xml") }
    Mock Invoke-BitwardenCLI -ParameterFilter {$args[0] -eq "get" -and $args[1] -eq "template" -and $args[2] -eq "item.login"} `
        -MockWith { return Import-Clixml (Join-Path $PSScriptRoot "item-templates" "item.login.xml") }
    Mock Invoke-BitwardenCLI -ParameterFilter {$args[0] -eq "get" -and $args[1] -eq "template" -and $args[2] -eq "item.securenote"} `
        -MockWith { return Import-Clixml (Join-Path $PSScriptRoot "item-templates" "item.securenote.xml") }
    Mock Invoke-BitwardenCLI -ParameterFilter {$args[0] -eq "get" -and $args[1] -eq "template" -and $args[2] -eq "item.card"} `
        -MockWith { return Import-Clixml (Join-Path $PSScriptRoot "item-templates" "item.card.xml") }
    Mock Invoke-BitwardenCLI -ParameterFilter {$args[0] -eq "get" -and $args[1] -eq "template" -and $args[2] -eq "item.identity"} `
        -MockWith { return Import-Clixml (Join-Path $PSScriptRoot "item-templates" "item.identity.xml") }
}

Describe "New-Secret" {
    Context "Get <Name> Template" -ForEach @(
        @{Name="Login"},
        @{Name="SecureNote"},
        @{Name="Card"},
        @{Name="Identity"}
    ) {
        BeforeAll {
            $template = New-Secret -Name $Name -SecretType $Name
            $prop = $Name.ToLower()
        }

        It "Template is Not Null" {
            $template | Should -Not -BeNullOrEmpty
        }
        It "Name is Correct" {
            $template.name | Should -Be $Name
        }
        It "SecretType is Correct" {
            $template.type | Should -Be $Name
        }
        It "<Name> Field is Not Null" {
            $template.$prop | Should -Not -BeNullOrEmpty
        }
        It "<Name> Field Contains Subtemplate" {
            $subTemplate = Import-Clixml (Join-Path $PSScriptRoot "item-templates" "item.${prop}.xml")
            Compare-Object -ReferenceObject $subTemplate -DifferenceObject $template.$prop | Should -BeNullOrEmpty
        }
    }
}
