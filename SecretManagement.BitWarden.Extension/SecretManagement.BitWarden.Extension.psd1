@{
    ModuleVersion = '0.2.0'
    RootModule = 'SecretManagement.BitWarden.Extension.psm1'
    FunctionsToExport = @(
        'Get-Secret',
        'Get-SecretInfo',
        'Remove-Secret',
        'Set-Secret',
        'Test-SecretVault',
        'Unlock-SecretVault'
        )
}
