function Set-Jwt {
    [CmdletBinding()]
    param ()
    if ($CONFIG._API.expires.AddMinutes(1) -lt (Get-Date)) {        
        $localToken = Get-Jwt
        $CONFIG._API.expires = $localToken.expires
        Set-Headers -Token $localToken.token
    }
}