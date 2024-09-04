BeforeAll {
    $BasePath = Join-Path $PSScriptRoot ".." ".."
    . (Join-Path $BasePath "private" "Get-CacheLocation.ps1")
    . (Join-Path $BasePath "private" "Sync-BitwardenVault.ps1")
    . (Join-Path $BasePath "private" "Invoke-BitwardenCLI.ps1")
    . (Join-Path $BasePath "private" "ConvertTo-BWEncoding.ps1")
    . (Join-Path $BasePath "classes" "BitwardenEnum.ps1")
    . (Join-Path $BasePath "classes" "BitwardenPasswordHistory.ps1")
}

Describe "Sync-BitwardenVault" {
    BeforeAll {
        $PesterCacheLocation = Join-Path $TestDrive "LastSyncedTime.txt"
        $ResyncCacheIfOlderThan = New-TimeSpan -Hours 3
        # Mock performing a vault sync
        Mock Invoke-BitwardenCLI { return $true } -ParameterFilter { $args[0] -eq "sync" -and $args[1] -eq "--quiet" }
        # Mock getting cache location.
        Mock Get-CacheLocation { return $PesterCacheLocation }
    }
    Context "First Run" {
        BeforeAll {
            # Have Test-Path Return $false as no cache file exists.
            Mock Test-Path { return $false }
            # Mock Having the Last Sync Date Be Now (as vault is synced during initial login)
            Mock Invoke-BitwardenCLI { return Get-Date -AsUTC -Format "yyyy-MM-ddTHH:mm:ss.fffZ" } -ParameterFilter {$args[0] -eq 'sync' -and $args[1] -eq '--last'}
        }
        BeforeEach { Sync-BitwardenVault $ResyncCacheIfOlderThan }
        It "Gets the Last Synced Time" {
            Should -Invoke -CommandName Invoke-BitwardenCLI -Times 1 -ParameterFilter {$args[0] -eq 'sync' -and $args[1] -eq '--last'}
        }
        It "Creates LastSyncedTime.txt" {
            $PesterCacheLocation | Should -Exist
        }
        It "Does Not Resync Fresh Vault Cache" {
            Should -Invoke -CommandName Invoke-BitwardenCLI -Times 0 -ParameterFilter {$args[0] -eq "sync" -and $args[1] -eq "--quiet" }
        }
    }
    Context "Existing Cache <Name> ResyncCacheIfOlderThan" -ForEach @(
        @{Name="Older Than"; HourOffset=-5; PerformsSync=$true},
        @{Name="Same As"; HourOffset=$ResyncCacheIfOlderThan; PerformsSync=$false},
        @{Name="Newer Than"; HourOffset=-1; PerformsSync=$false}
    ) {
        BeforeAll {
            Mock Test-Path { return $true }
            # Create Cache File
            (Get-Date -AsUTC).AddHours($HourOffset).ToString("o") | Out-File -FilePath $PesterCacheLocation -NoNewline
        }
        BeforeEach { Sync-BitwardenVault $ResyncCacheIfOlderThan }
        It "Performs Resync - <PerformsSync>" {
            Should -Invoke -CommandName Invoke-BitwardenCLI -ParameterFilter {$args[0] -eq "sync" -and $args[1] -eq "--quiet" } `
                -Times ($PerformsSync ? 1 : 0)
        }
        It "Does Not Query Bitwarden CLI for LastSyncedTime" {
            Should -Invoke -CommandName Invoke-BitwardenCLI -Times 0 -ParameterFilter {$args[0] -eq 'sync' -and $args[1] -eq '--last'}
        }

    }
}
