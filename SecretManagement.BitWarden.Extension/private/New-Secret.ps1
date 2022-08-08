<#
.SYNOPSIS
    Retrieve a new secret template.
.DESCRIPTION
    Retrieves a new secret template for you to edit and submit to the vault as a new secret.
.PARAMETER Name
    The name of the secret.  This is not the username.
.PARAMETER SecretType
    The type of secret you are creating.  This aligns with [BitwardenItemType] and can be:
        Login, SecureNote, Card, or Identity.
.EXAMPLE
    New-Secret "MyTest" Login
    Retrieves a login secret template named "MyTest".
#>
function New-Secret {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [string] $Name,
        [ValidateSet("Login","SecureNote","Card","Identity")]
        [string] $SecretType
    )

    $Secret = Invoke-BitwardenCLI get template item -AsPlainText
    $Secret.name = $Name

    switch($SecretType) {
        "Login" {
            $Secret.type = [BitwardenItemType]::Login
            $Secret.login = Invoke-BitwardenCLI get template item.login -AsPlainText
            break
        }
        "SecureNote" {
            $Secret.type = [BitwardenItemType]::SecureNote
            $Secret.securenote = Invoke-BitwardenCLI get template item.securenote -AsPlainText
            break
        }
        "Card" {
            $Secret.type = [BitwardenItemType]::Card
            $Secret.card = Invoke-BitwardenCLI get template item.card -AsPlainText
            break
        }
        "Identity" {
            $Secret.type = [BitwardenItemType]::Identity
            $Secret.identity = Invoke-BitwardenCLI get template item.identity -AsPlainText
            break
        }
    }

    return $Secret
}