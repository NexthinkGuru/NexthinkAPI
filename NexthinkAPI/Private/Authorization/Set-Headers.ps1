function Set-Headers {
    [CmdletBinding()]
    param ()
    if ($CONFIG._API.expires.AddMinutes(1) -lt (Get-Date)) {        
        $localToken = Get-Jwt
        $CONFIG._API.expires = $localToken.expires
        $CONFIG._API.headers.Authorization = "Bearer " + $localToken.token
    }
}