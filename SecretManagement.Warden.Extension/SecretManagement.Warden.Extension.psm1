#Get public and private function definition files.
$Classes = @( Get-ChildItem -Path $PSScriptRoot\classes\*.ps1 -ErrorAction SilentlyContinue )
$Public  = @( Get-ChildItem -Path $PSScriptRoot\public\*.ps1 -ErrorAction SilentlyContinue  )
$Private = @( Get-ChildItem -Path $PSScriptRoot\private\*.ps1 -ErrorAction SilentlyContinue )

#Dot source the files
Foreach($import in @($Classes + $Public + $Private))
{
	Try { . $import.fullname }
	Catch { Write-Error -Message "Failed to import function $($import.fullname): $_" }
}

# Here I might...
# Read in or create an initial config file and variable
# Export Public functions ($Public.BaseName) for WIP modules
# Set variables visible to the module and its functions only

# *Verify Existence of and Get CommandInfo for the Bitwarden CLI.
# ?If the path is specified by $env:BITWARDEN_CLI_PATH then use that. Else search for it in the current session. If neither exists throw an error.
if (!($env:BITWARDEN_CLI_PATH -and ($BitwardenCLI = Get-Command $env:BITWARDEN_CLI_PATH -CommandType Application -ErrorAction SilentlyContinue)) `
    -and (!($BitwardenCLI = Get-Command -Name bw -CommandType Application -ErrorAction Ignore)))
{
    if( $IsWindows ) { $platform = "windows" }
    elseif ( $IsMacOS ) { $platform = "macos" }
    else { $platform = "linux" }

    Write-Error "No Bitwarden CLI found in your path, either specify `$env:BITWARDEN_CLI_PATH or put bw.exe in your path. If the CLI is not installed, you can install it using scoop, chocolatey, npm, snap, or winget. You can also download it directly from: https://vault.bitwarden.com/download/?app=cli&platform=$platform" -ErrorAction Stop
}

# *Perform version check ONCE during module import.
Test-CLIVersion -BitwardenCLI $BitwardenCLI -MinSupportedVersion '2022.8.0'

Export-ModuleMember -Function $Public.Basename
