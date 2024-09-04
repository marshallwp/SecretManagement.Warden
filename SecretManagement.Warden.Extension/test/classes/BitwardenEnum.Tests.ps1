BeforeAll {
    . (Join-Path $PSScriptRoot ".." ".." "classes" "BitwardenEnum.ps1")
}

Describe "Enums Existence" {
    BeforeAll {
        $EnumList = [AppDomain]::CurrentDomain.GetAssemblies() |
            Where-Object {
                $_.ManifestModule -like "RefEmit_InMemoryManifestModule" -and
                $_.CustomAttributes.NamedArguments.TypedValue.Value -like "*BitwardenEnum.ps1"
            } | Select-Object -ExpandProperty ExportedTypes
    }
    It "<Name> Exists" -ForEach @(
        @{Name="BitwardenMfaMethod"},
        @{Name="BitwardenItemType"},
        @{Name="BitwardenUriMatchType"},
        @{Name="BitwardenFieldType"},
        @{Name="BitwardenOrganizationUserType"},
        @{Name="BitwardenOrganizationUserStatus"}
    ) {
        $EnumList.Name | Should -Contain $Name
    }
}
