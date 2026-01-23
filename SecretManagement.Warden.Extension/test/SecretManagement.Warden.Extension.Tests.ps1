Describe 'Extension Module Manifest Tests' {
	BeforeAll {
        $Script:ModuleInformation = Test-ModuleManifest -Path "$PSScriptRoot\..\SecretManagement.Warden.Extension.psd1"
        $Script:ParentModuleInformation = Test-ModuleManifest -Path "$PSScriptRoot\..\..\SecretManagement.Warden.psd1"
    }

    It 'Version Consistent with Parent Module' {
        $Script:ModuleInformation.Version | Should -Be $Script:ParentModuleInformation.Version
    }
	It 'Exports Functions' {
		$Script:ModuleInformation.ExportedFunctions.Count | Should -BeGreaterThan 0
	}
    It 'Release Notes Updated' {
        $LatestReleaseNotes = (Find-PSResource -Name SecretManagement.Warden).ReleaseNotes
        $ReleaseNotesUpdated = $Script:ParentModuleInformation.PrivateData.PSData.ReleaseNotes -ine $LatestReleaseNotes
        $ReleaseNotesUpdated | Should -BeTrue -Because "Release Notes must be updated for new releases"
    }
}
