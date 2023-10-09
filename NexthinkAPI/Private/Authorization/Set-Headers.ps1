function Set-Headers {
    [CmdletBinding()]
    param ()
    if ($Config._API.expires.AddMinutes(1) -lt (Get-Date)) {        
        $localToken = Get-Jwt
        $Config._API.expires = $localToken.expires
        $Config._API.headers.Authorization = "Bearer " + $localToken.token
    }
}