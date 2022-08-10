# SecretManagement extension for BitWarden
This module is an extension vault for the PowerShell SecretManagement module. It wraps around the official [Bitwarden CLI](https://github.com/bitwarden/clients/tree/master/apps/cli) to interface with Bitwarden and Vaultwarden instances. This module works over all supported PowerShell platforms on Windows, Linux, and macOS.

Supported Commands:
`Get-Secret`, `Get-SecretInfo`, `Remove-Secret`, `Set-Secret`, `Test-SecretVault`, `Unlock-SecretVault`

Unsupported Commands:
`Set-SecretInfo`


> **NOTE: This is not an official Bitwarden project.**

## Prerequisites

Download and Install

* [PowerShell](https://github.com/PowerShell/PowerShell)
* The [`bitwarden-cli`](https://bitwarden.com/help/article/cli/#download-and-install)

## Installation

This module has not yet been published to the PowerShell Gallery.  To install, clone/download the repo and specify it directly when registering the vault.

Example:
`Register-SecretVault -Name "warden" -ModuleName "C:\Git\SecretManagement.BitWarden"`

## Registration

Once you have it installed,
you need to register the module as an extension:

```pwsh
Register-SecretVault -ModuleName SecretManagement.BitWarden
```
If you wish to use any non-default configurations, put them in a hashtable and pass that to `Register-SecretVault` with the `-VaultParameters` parameter.

Example:
```pwsh
$VaultParameters = @{
	ExportObjectsToSecureNotesAs = "CliXml"
	EncodingOfSecrets = "unicode"
	MaximumObjectDepth = 4
	ResyncCacheIfOlderThan = New-TimeSpan -Hours 2
}
Register-SecretVault -ModuleName SecretManagement.BitWarden -VaultParameters $VaultParameters
```


Optionally, you can set it as the default vault by also providing the
`-DefaultVault`
parameter.

### Registration Vault Parameters
When registering the vault you can include a HashTable of vault parameters to configure client behavior.  These are passed to implementing functions as `$AdditionalParameters`.

**Supported Vault Parameters**

| Name | Description | Type | Possible Values | Default |
| ---- | ----------- | -----| --------------- | ------- |
| **ExportObjectsToSecureNotesAs** | Changes what PowerShell HashTables are converted into so they can be stored as a Secure Note in the vault.<br><br>Defaults to JSON for interoperability with other languages.  However, CliXml has superior type support and can be used to store an *exact* copy of the object, including custom typing, in the vault. See [Export-Clixml](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/export-clixml) for details. | [String](https://docs.microsoft.com/en-us/dotnet/api/system.string) | CliXml, JSON | JSON |
| **EncodingOfSecrets** | Changes the character encoding of secrets for functions that support it. This should be set to match the encoding of your vault storage (or be a subset, i.e. ASCII is a subset of UTF-8). Supports all [PowerShell supported character encodings](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_character_encoding). | [String](https://docs.microsoft.com/en-us/dotnet/api/system.string) | ascii, bigedianunicode, bigendianutf32, oem, unicode, utf7, utf8, utf8BOM, utf8NoBom, utf32 | utf8BOM |
| **MaximumObjectDepth** | Specifies how many levels of contained objects are included in the CliXml/JSON representation. | [Int32](https://docs.microsoft.com/en-us/dotnet/api/system.int32) | 1–100 | 2 |
| **ResyncCacheIfOlderThan** | A System.TimeSpan object indicating the amount of time that is allowed to pass before the local cache is considered expired.  After expiry, the vault will be synced before running any further commands. | [System.TimeSpan](https://docs.microsoft.com/en-us/dotnet/api/system.timespan) | Any System.TimeSpan | `New-TimeSpan -Hours 3` |

## Vault Syncing
The Bitwarden CLI always writes data directly to the vault, however it always retrieves data from a cache.  That cache is automatically refreshed every time you login, but must be manually refreshed otherwise. Within this module you can force a sync by running `Unlock-SecretVault` or `Test-SecretVault`.  Otherwise sync is governed by the `ResyncCacheIfOlderThan` setting.

As a last resort you can call the Bitwarden CLI directly to force the sync with `bw sync`.

## Special Thanks
Special Thanks to @TylerLeonhardt for publishing a baseline for this module extension. Please check out his [`LastPass Extention`](https://github.com/TylerLeonhardt/SecretManagement.LastPass)

Special thanks to @realslacker for his excellent [bitwarden cli wrapper](https://github.com/realslacker/BitwardenWrapper).  A stripped down and heavily modified version of it was utilized to replace `Invoke-bwcmd`.
