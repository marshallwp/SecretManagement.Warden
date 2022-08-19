class BitwardenPasswordHistory {
    [datetime]$LastUsedDate = [datetime]::Now
    [securestring]$Password

    [string] Reveal() {
        return ConvertFrom-SecureString $this.Password -AsPlainText
    }

    BitwardenPasswordHistory() {}

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "", Justification = "Converting received plaintext password to SecureString")]
    BitwardenPasswordHistory( [pscustomobject]$JsonObject ) {
        $this.LastUsedDate = $JsonObject.LastUsedDate
        $this.Password = ConvertTo-SecureString -String $JsonObject.Password -AsPlainText -Force
    }
}
