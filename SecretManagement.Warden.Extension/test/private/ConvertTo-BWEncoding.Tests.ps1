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

    Context "Verbose Output" {
        It "<InputType>: [Verbose] <Expected>" -ForEach @(
            @{ InputType="Int32"; Case=32; Expected=@('Object is already a JSON string', 'Converting JSON to Base64 encoding') },
            @{ InputType="String"; Case=$str; Expected="Converting JSON to Base64 encoding" },
            @{ InputType="Base64"; Case=$strB64; Expected="Object is already Base64 encoded" },
            @{ InputType="HashTable"; Case=$obj; Expected=@('Converting object to JSON', 'Converting JSON to Base64 encoding') },
            @{ InputType="JSON"; Case=$json; Expected='Converting JSON to Base64 encoding' },
            @{ InputType="JSON (Base64)"; Case=$jsonB64; Expected="Object is already Base64 encoded" }
        ) {
            $tmpFile = New-TemporaryFile
            ConvertTo-BWEncoding $Case -Verbose 4> $tmpFile.FullName
            Get-Content $tmpFile | Should -Be $Expected
            Remove-Item $tmpFile
        }
    }
}
