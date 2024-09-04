BeforeAll {
    . (Join-Path $PSScriptRoot ".." ".." "private" "ConvertTo-BWEncoding.ps1")
}

BeforeDiscovery {
    $str = "TestString"
    $strBytes = [System.Text.Encoding]::UTF8.GetBytes($str)
    $strB64 = [Convert]::ToBase64String($strBytes)
    #----------------------------
    $obj = @{key = "value"}
    $json = $obj | ConvertTo-Json -Compress
    $jsonBytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $jsonB64 = [Convert]::ToBase64String($jsonBytes)
}

Describe "ConvertTo-BWEncoding" {
    Context "Convert to Base64" {
        It "Returns Base64 from <InputType>" -TestCases @(
            @{ InputType='String'; Case=$str; Expected=$strB64 },
            @{ InputType='Base64'; Case=$strB64; Expected=$strB64 },
            @{ InputType='HashTable'; Case=$obj; Expected=$jsonB64 },
            @{ InputType='JSON'; Case=$json; Expected=$jsonB64 },
            @{ InputType="JSON (Base64)"; Case=$jsonB64; Expected=$jsonB64 }
        ) {
            ConvertTo-BWEncoding $Case | Should -BeExactly $Expected
        }
    }

    Context "Data uses UTF-8 Encoding (bw.exe requirement)" {
        It "Encodes <InputType> in UTF-8" -TestCases @(
            @{ InputType='String'; Case=$str; Expected=$strBytes },
            @{ InputType='HashTable'; Case=$obj; Expected=$jsonBytes },
            @{ InputType='JSON'; Case=$json; Expected=$jsonBytes }
        ) {
            $sample = [Convert]::FromBase64String((ConvertTo-BWEncoding $Case))
            $sample | Should -Be $Expected
        }
    }
}
