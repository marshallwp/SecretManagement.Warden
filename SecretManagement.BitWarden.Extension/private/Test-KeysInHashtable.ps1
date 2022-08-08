function Test-KeysInHashtable {
    [CmdletBinding()]
    Param(
        # Hashtable object to search
        [hashtable]$Hashtable,
        # List of keys 
        [string[]]$Keys,
        # If specified, test will fail if any of the keys are missing.
        [switch]$MatchAll
    )

    [bool]$ContainsKey = $false
    foreach($prop in $Keys) {
        if($MatchAll) {
            if($Hashtable.ContainsKey($prop)) { $ContainsKey = $true }
            else { $ContainsKey = $false;  break }
        }
        elseif($Hashtable.ContainsKey($prop)) { $ContainsKey = $true; break } 
    }
    return $ContainsKey
}