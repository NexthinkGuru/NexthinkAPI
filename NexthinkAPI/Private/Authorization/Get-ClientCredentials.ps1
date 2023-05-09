function Get-ClientCredentials {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String]$Target
    )
    $storedCredentials = Get-StoredCredential -Target $Target
    if ($storedCredentials -and $null -ne $storedCredentials.UserName -and $null -ne $storedCredentials.Password ) {
        $userName = $storedCredentials.UserName
        $securePassword = $storedCredentials.Password
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
        $unsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

        return @{ clientId = $userName; clientSecret = $unsecurePassword }
    } else {
        throw "Credentials not found or they are empty for Target: $Target"
    }
}
