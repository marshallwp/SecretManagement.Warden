Describe 'Module Manifest Tests' {
	BeforeAll { $Script:ModuleInformation = Test-ModuleManifest -Path "$PSScriptRoot\..\SecretManagement.Warden.psd1" }

	It 'Passes Test-ModuleManifest' {
		$Script:ModuleInformation | Should -Not -BeNullOrEmpty
		$? | Should -Be $true
	}
	It 'Copyright Notice Is Valid' {
		$Script:ModuleInformation.Copyright | Should -Match "(©|\(c\)){1}\ [\d]{4}\ $([regex]::Escape($Script:ModuleInformation.CompanyName))[.]?\ All\ rights\ reserved\."
	}
	It 'Copyright Year Is Current' {
		($Script:ModuleInformation.Copyright | Select-String -Pattern "\d{4}").Matches[0].Value | Should -Be (Get-Date).Year -Because "Copyright year should be updated for new dev work"
	}
	It 'CompanyName = Industrial Info Resources, Inc.' {
		$Script:ModuleInformation.CompanyName | Should -BeExactly 'Industrial Info Resources, Inc.'
	}
	It 'Contains Author' {
		$Script:ModuleInformation.Author | Should -Not -BeNullOrEmpty
	}
	It 'Contains Description' {
		$Script:ModuleInformation.Description | Should -Not -BeNullOrEmpty
	}
}
