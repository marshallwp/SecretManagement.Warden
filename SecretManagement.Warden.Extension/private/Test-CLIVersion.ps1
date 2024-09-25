<#
.SYNOPSIS
    Checks Bitwarden CLI version against blacklist.
.DESCRIPTION
    Long description
.EXAMPLE
    An example
.NOTES
    General notes
#>
function Test-CLIVersion {
    [CmdletBinding()]
    Param(
        # CommandInfo of the Bitwarden CLI. Returned from Get-Command or dehydrated from Import-CliXml.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if($_.PSTypeNames -match '^(?:Deserialized\.)?System\.Management\.Automation\.CommandInfo$')
            { return $true }
            else { throw "Cannot convert the `"$_`" value of type `"$iptType`" to type `"System.Management.Automation.CommandInfo`"." }
        })]
        [PSObject]$BitwardenCLI,
        # Minimum Supported Version of the Bitwarden CLI.
        [ValidateNotNullOrEmpty()]
        [Version]$MinSupportedVersion = '2022.8.0'
    )

#region Get CLI Version
    # Get the Version number from file metadata if possible.
    [Version]$CurrentVersion = $BitwardenCLI.Version

    # ?Find the version elsewhere if the file version would fail the test. Workaround for how the file version is not always the cli version.
    if( $CurrentVersion -lt $MinSupportedVersion ) {
        # Handle the various shims
        # ?The Brew CLI is rather fast so we use it to get version number
        $HomebrewPrefix = $env:HOMEBREW_PREFIX ?? "/home/linuxbrew/.linuxbrew"
        if ( $BitwardenCLI.Source -eq "$HomebrewPrefix/bin/bw" -and (Get-Command brew -ErrorAction Ignore))
        {
            $CurrentVersion = ((brew list bitwarden-cli --versions) -split ' ')[1]
        }
        # ?The Chocolatey CLI is very slow, so we prefer querying bw directly if needed.
        # if ( $BitwardenCLI.Source -eq (Join-Path $env:ProgramData "chocolatey" "bin" "bw.exe") `
        #     -and (Get-Command choco -ErrorAction Ignore))
        # {
        #     $CurrentVersion = (choco info bitwarden-cli --local-only --limit-output).Split("|")[1]
        # }
        # ?npm creates a ps1 shim that is stripped of all version info. The CLI is fast though.
        elseif ( $BitwardenCLI.Name -eq "bw.ps1" -and (Get-Command npm -ErrorAction Ignore)) {
            $CurrentVersion = (npm view -g @bitwarden/cli version)
        }
        # ?Scoop shims eliminate version numbers, so we ask scoop for the true version.
        elseif( $BitwardenCLI.Source -like "*\scoop\shims\bw.exe" -and (Get-Command scoop -ErrorAction Ignore)) {
            $CurrentVersion = (scoop list bitwarden-cli 6> $null).Version ?? $CurrentVersion
        }
        # ?Getting the version from snap is very fast, so ask it for that.
        elseif( $BitwardenCLI.Source -like "*/snapd/snap/bin/bw" -and (Get-Command snap -ErrorAction Ignore) ) {
            # Query snap for a list containing only the bw command.
            $snapVerChk = snap list bw
            # Get the position of the Version Header and treat that as the startPos
            $startPos = ($snapVerChk | Select-String Version).Matches[0].Index
            # Get the position of the first space after startPos on line 2
            $endPos = $snapVerChk[1].Substring($startPos).IndexOf(' ')
            # The version is the text between the startPos and endPos on line 2.
            $CurrentVersion = $snapVerChk[1].Substring($startPos, $endPos) ?? $CurrentVersion
        }
        # ?WinGet shims have the wrong version, and the winget CLI is slow.  Disabled in favor of querying bw.exe instead.
        # elseif( $BitwardenCLI.Source -like "*\WinGet\Links\bw.exe" -or <# Machine Scope #>
        #         $BitwardenCLI.Source -like "*\Winget\Packages\*\bw.exe" <# User Scope #>) {
        #     $wingetVerChk = winget list --id Bitwarden.CLI
        #     $startPos = ($wingetVerChk | Select-String Version).Matches[0].Index
        #     $endPos = ($wingetVerChk | Where-Object {![String]::IsNullOrWhiteSpace($_) -and $_.Length -gt $startPos})[2].Substring($startPos).IndexOf(' ')
        #     $CurrentVersion = $snapVerChk[1].Substring($startPos, $endPos) ?? $CurrentVersion
        # }
        # ?If all other methods fail, ask bw.exe what version it is. This is a surprisingly slow process.
        else {
            $CurrentVersion = (.$BitwardenCLI --version) ?? $CurrentVersion
        }
    }
#endregion Get CLI Version


#region Version Warnings
    # Default Warning Message templates. Will be used if a localized variant cannot be found in the localization subdirectory.
    #culture="en-US"
    $Warnings = DATA {@{
        WarnOutdated        = "Your bitwarden-cli is version {0} and is out of date. Please upgrade to at least version {1}."
        WarnSpecificVersion = "Your bitwarden-cli is version {0}. This version of the CLI has a known issue affecting [{1}], which is used by [{2}]."
        WarnVersionRange    = "Your bitwarden-cli is version {0}. Versions {1} - {2} of the CLI have a known issue affecting [{3}], which is used by [{4}]."
        See                 = "See: {0}."
        StrongAction        = "It is `e[3mstrongly`e[23m recommended that you move to another version."
    }}
    Import-LocalizedData -BindingVariable Warnings -BaseDirectory (Join-Path $PSScriptRoot "localization") -ErrorAction Ignore

    if ( $CurrentVersion -lt $MinSupportedVersion ) {
        Write-Warning ($Warnings.WarnOutdated -f $CurrentVersion, $MinSupportedVersion)
    }
    elseif ( $CurrentVersion -ge '2023.12.0' -and $CurrentVersion -le '2023.12.1' ) {
        $warn = "{0} {1} {2}" -f ($Warnings.WarnVersionRange -f $CurrentVersion, '2023.12.0', '2023.12.1', 'bw list', 'Test-SecretVault'),
                                 ($Warnings.See -f 'https://github.com/bitwarden/clients/issues/7126'),
                                  $Warnings.StrongAction
        Write-Warning $warn
    }
    elseif ( $CurrentVersion -ge '2024.6.1' -and $CurrentVersion -le '2024.7.1' ) {
        $warn = "{0} {1} {2}" -f ($Warnings.WarnVersionRange -f $CurrentVersion, '2024.6.1', '2024.7.1', 'bw unlock', 'Unlock-SecretVault'),
                                 ($Warnings.See -f 'https://github.com/bitwarden/clients/issues/9919'),
                                  $Warnings.StrongAction
        Write-Warning $warn
    }
#endregion Version Warnings
}
