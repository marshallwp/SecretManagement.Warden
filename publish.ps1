#TODO: Take the time to go through this and figure out how it is supposed to work.

[CmdletBinding()]
param (
    [Parameter()]
    [switch]
    $Test,

    [Parameter()]
    [switch]
    $Package,

    [Parameter()]
    [switch]
    $Publish
)

Push-Location $PSScriptRoot

if ($Test) {
    Invoke-Pester test
}

if ($Package) {
    $outDir = Join-Path 'out' 'SecretManagement.BitWarden'
    Remove-Item out -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

    @(
        'SecretManagement.BitWarden.Extension'
        'SecretManagement.BitWarden.psd1'
        'LICENSE.txt'
        'README.md'
    ) | ForEach-Object {
        Copy-Item -Path $_ -Destination (Join-Path $outDir $_) -Force -Recurse
    }
}

if ($Publish) {
    Write-Host -ForegroundColor Green "Publishing module... here are the details:"
    $moduleData = Import-Module -Force ./out/SecretManagement.BitWarden -PassThru
    Write-Host "Version: $($moduleData.Version)"
    Write-Host "Prerelease: $($moduleData.PrivateData.PSData.Prerelease)"
    Write-Host -ForegroundColor Green "Here we go..."

    $CodeSigningSecret = (Invoke-BitwardenCLI get item $SecretID).login
    $cert = Get-PfxCertificate -FilePath $CodeSigningSecret.uris[0].uri -Password $CodeSigningSecret.password

    Get-ChildItem -Filter "*.ps?1" -File | Select-Object -ExpandProperty FullName | 
        Set-AuthenticodeSignature -Certificate $cert -TimestampServer "http://timestamp.sectigo.com"

    Publish-Module -Path ./out/SecretManagement.BitWarden -NuGetApiKey (Get-Secret -Name PowershellGalleryAPIKey)
}

Pop-Location
