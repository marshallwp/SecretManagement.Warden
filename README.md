# SecretManagement extension for BitWarden
This module is an extension vault for the [Microsoft.PowerShell.SecretManagement](https://www.powershellgallery.com/packages/Microsoft.PowerShell.SecretManagement) module. It wraps around the official [Bitwarden CLI](https://github.com/bitwarden/clients/tree/master/apps/cli) to interface with Bitwarden and Vaultwarden instances. This module works over all supported PowerShell platforms on Windows, Linux, and macOS.

Supported Commands:
`Get-Secret`, `Get-SecretInfo`, `Remove-Secret`, `Set-Secret`, `Test-SecretVault`, `Unlock-SecretVault`

Unsupported Commands:
`Set-SecretInfo`


> **NOTE: This is not an official Bitwarden project.**

## Prerequisites
Download and Install

<table style="text-align: center;">
<tbody>
<tr>
	<th colspan="2">PowerShell 7+ From:</th>
</tr>
<tr>
	<td>
		<a href='https://www.microsoft.com/store/apps/9MZ1SNWT0N5D'>
			<img src='https://developer.microsoft.com/store/badges/images/English_get-it-from-MS.png' alt='Get PowerShell from the Microsoft Store' width="142px" height="52px"/>
		</a>
	</td>
	<td>
		<a href="https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell">Multiplatform Install Instructions</a>
	</td>
</tr>
</tbody>
</table>

<table>
<tbody>
<tr>
	<th scope="row" colspan="6">The Latest version of the Bitwarden CLI From:</th>
</tr>
<tr>
	<td>
		<a href="https://www.npmjs.com/package/@bitwarden/cli">
			<img src="https://raw.githubusercontent.com/npm/logos/master/npm%20logo/npm-logo-red.svg" alt='Get Bitwarden CLI from NPM' height="30px"/>
		</a>
	</td>
	<td>
		<a href="https://scoop.sh/#/apps?q=&quot;bitwarden-cli&quot;">
			<div style="font-size: 20px; color: black; background: #d7d4db">
				<img src="https://avatars.githubusercontent.com/u/16618068?s=52" style='vertical-align: middle'/> Scoop
			</div>
		</a>
	</td>
	<td>
		<a href="https://community.chocolatey.org/packages/bitwarden-cli">
			<img src="https://chocolatey.org/assets/images/global-shared/logo-square.svg" height="52px"/>
		</a>
	</td>
	<td>
		<a href="https://snapcraft.io/bw">
			<img src="https://snapcraft.io/static/images/badges/en/snap-store-black.svg" alt='Get Bitwarden CLI from the Snap Store' height="52px"/>
		</a>
	</td>
	<td><a href="https://learn.microsoft.com/en-us/windows/package-manager/winget/">winget</a><br>
		<code>winget install -e Bitwarden.CLI --source winget</code>
	</td>
	<td>Direct Download<br>
		<a href="https://vault.bitwarden.com/download/?app=cli&platform=windows">Windows</a> |
		<a href="https://vault.bitwarden.com/download/?app=cli&platform=macos">macOS</a> |
		<a href="https://vault.bitwarden.com/download/?app=cli&platform=linux">Linux</a>
	</td>
</tr>
</tbody>
</table>

## Bitwarden CLI Setup
After installing the bitwarden-cli, use native [config](https://bitwarden.com/help/cli/#config) commands to configure it as needed.  In particular, if you run a self-hosted instance of Bitwarden/Vaultwarden you need to specify the URL to that via:
```pwsh
bw config server "https://your.bw.domain.com"
```

Lastly, the `SecretManagement` module can only handle unlock operations, not login operations.  As such you will need to login before you can utilize this extension.

### (Recommended) Utilize API Key for Login
This Module is designed for unattended usage and expects you to implement login via [API Key environmental variables](https://bitwarden.com/help/cli/#using-an-api-key).  If setup this way, the `SecretManagement.Warden` extension will use these credentials to silently resolve any "You are not logged in" errors.  NOTE: While this means you will effectively always be logged in, you will still need to unlock the vault with your password every session to gain access to secrets.

To configure automatic API Key usage follow the steps below:

1. Retrieve your personal API Key. (See [Get your personal API key](https://bitwarden.com/help/personal-api-key/#get-your-personal-api-key) for more details than the brief below).
	1. Open the web vault on your Bitwarden/Vaultwarden instance and login.
	2. Select the profile icon and click _Account Settings_ from the dropdown.
	3. Under the Account Settings menu, select the _Security_ page and _Keys_ tab.
	4. Click the _View API Key_ button at the bottom.
2. Permanently set the required environmental variables through the GUI via _Advanced System Properties_ or run the following PowerShell commands.
	```pwsh
	[Environment]::SetEnvironmentVariable("BW_CLIENTID",'MyClientID',"User")
	[Environment]::SetEnvironmentVariable("BW_CLIENTSECRET",'SuperSecret',"User")
	```

#### Verify Proper Configuration
Check that everything is setup correctly by running the command: `bw login --check`  If the cli tells you that you are logged in everything is working.  If not, try the following troubleshooting steps.

* Open a PowerShell session.
* Run `bw login --apikey`.  If an error about the server is returned, you likely made a typo when specifying the server URL.  Fix this by re-running `bw config server "https://your.bw.domain.com"`
* Run `gci env:BW_CLIENT*`. This should return at least two entries: **BW_CLIENTID** and **BW_CLIENTSECRET**.  If either are missing, go through the steps detailed in [Utilize API Key for Login](#recommended-utilize-api-key-for-login) again.

### (Not Recommended) Use Bitwarden CLI to Login
If running interactively you can run `bw login` to bring up a login prompt.  Unlike API Keys, this will only last a single session.

While the prompt is the only _secure_ way to use `bw login` directly, you _can_ automate it to run insecurely via `bw login [email] [password] --method <method> --code <code>` as described [here](https://bitwarden.com/help/cli/#using-email-and-password).

> REMEMBER:
> * All commands you run will be saved to session history. While this is cleared every time you close the terminal, it is still preferable to avoid adding secrets to it in the first place.
> * All commands that do not contain the words: `password`, `asplaintext`, `token`, `apikey`, or `secret` will be saved into the [PSReadLine History](https://docs.microsoft.com/en-us/powershell/module/psreadline/about/about_psreadline?view=powershell-7.2#command-history) file.
>   * This one can be really bad as the file is stored unencrypted long-term and `bw login` does not contain any exclusion words.
>   * Not an issue when using the `SecretManagement` module or extensions as all public commands include the word "secret" in them and all private commands are run in a isolated session that does not store history.

## Module Installation

This module has been published to the [PowerShell Gallery](https://www.powershellgallery.com/packages/SecretManagement.Warden).  To install it and its PowerShell dependencies from there run:
```pwsh
Install-PSResource -Name SecretManagement.Warden
# OR
Install-Module -Name SecretManagement.Warden
```
### Manual Install
Alternatively, manually install its Microsoft.PowerShell.SecretManagement dependency then download the latest [release](https://gitlab.industrialinfo.com/wmarshall/SecretManagement.Warden/-/releases) (Do not clone the repo; code is only signed during the release process).  Open the downloaded file, open the only directory therein, and extract the contents of that subdirectory to the directory:

* `$HOME\Documents\PowerShell\Modules\SecretManagement.Warden` (Windows)
* `$HOME/.local/share/powershell/Modules/SecretManagement.Warden` (Linux or Mac)

Then Register the vault with SecretManagement as usual, e.g. `Register-SecretVault -Name "warden" -ModuleName "SecretManagement.Warden"`

### Optional Settings
If you wish to use any non-default configurations, put them in a hashtable and pass that to `Register-SecretVault` with the `-VaultParameters` parameter.

Example:
```pwsh
$VaultParameters = @{
	ExportObjectsToSecureNotesAs = "CliXml"
	MaximumObjectDepth = 4
	ResyncCacheIfOlderThan = New-TimeSpan -Hours 2
}
Register-SecretVault -Name "warden" -ModuleName SecretManagement.Warden -VaultParameters $VaultParameters
```

Optionally, you can set it as the default vault by also providing the `-DefaultVault` parameter, though this is assumed if you've never registered another vault.

### Registration Vault Parameters
When registering the vault you can include a HashTable of vault parameters to configure client behavior.  These are passed to implementing functions as `$AdditionalParameters`.

**Supported Vault Parameters**

| Name | Description | Type | Possible Values | Default |
| ---- | ----------- | -----| --------------- | ------- |
| **ExportObjectsToSecureNotesAs** | Changes what PowerShell HashTables are converted into so they can be stored as a Secure Note in the vault.<br><br>Defaults to JSON for interoperability with other languages.  However, CliXml has superior type support and can be used to store an *exact* copy of the hashtable, including custom typing, in the vault. See [Export-Clixml](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/export-clixml) for details. | [String](https://docs.microsoft.com/en-us/dotnet/api/system.string) | CliXml, JSON | JSON |
| **MaximumObjectDepth** | Specifies how many levels of contained objects are included in the CliXml/JSON representation. | [Int32](https://docs.microsoft.com/en-us/dotnet/api/system.int32) | 1–100 | 2 |
| **OrganizationID** | If specified, the vault will only work with the subset of secrets owned by the vault Organization with this ID.†  You can retrieve these values via `bw list organizations`. | [Guid](https://docs.microsoft.com/en-us/dotnet/api/system.guid) | Any Guid | none |
| **ResyncCacheIfOlderThan** | A TimeSpan object indicating the amount of time that is allowed to pass before the local cache is considered expired.  After expiry, the vault will be synced before running any further commands. | [TimeSpan](https://docs.microsoft.com/en-us/dotnet/api/system.timespan) | Any TimeSpan | `New-TimeSpan -Hours 3` |

† While you cannot specify the OrganizationID on a per query basis, you _can_ register multiple vaults with different OrganizationIDs and specify those when running the query, which has much the same effect.

## Vault Syncing
The Bitwarden CLI always writes data directly to the vault, however it always retrieves data from a cache.  That cache is automatically refreshed every time you login, but must be manually refreshed otherwise. Within this module you can force a sync by running `Test-SecretVault`.  Otherwise sync is governed by the `ResyncCacheIfOlderThan` setting.

As a last resort you can call the Bitwarden CLI directly to force the sync with `bw sync`.

## Known Issues
When you first register a vault using this extension, commands like `Test-SecretVault` or `Get-Secret` may report that it is unable to run on the registered vault.  This error message is incorrect, in actuality the vault is just locked.  To resolve the issue, run `Unlock-SecretVault`.  Future output from `Test-SecretVault` should correctly notify you that the vault is locked.

`Unlock-SecretVault` will stall if you specified an invalid URL when configuring the location of the server.

When automating usage of this Module use the API key for login.  This way you can assume the user is logged in and that if `Test-SecretVault` returns `false` it's because the vault is either locked or inaccessible.

## Special Thanks
Special Thanks to @TylerLeonhardt for publishing a baseline for this module extension. Please check out his [`LastPass Extention`](https://github.com/TylerLeonhardt/SecretManagement.LastPass)

Special thanks to @realslacker for his excellent [bitwarden cli wrapper](https://github.com/realslacker/BitwardenWrapper).  A stripped down and heavily modified version of it was utilized to replace `Invoke-bwcmd`.
