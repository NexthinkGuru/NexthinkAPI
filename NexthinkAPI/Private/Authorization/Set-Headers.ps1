function Set-Headers {
    [CmdletBinding()]
    param ([string] $Type)

    if (($Config._API.expires -eq 0) -or 
        ($Config._API.expires.AddMinutes(-1) -lt (Get-Date))) {       
        $localToken = Get-Jwt
        $Config._API.expires = $localToken.expires
        $Config._API.headers.Authorization = "Bearer " + $localToken.token
    }
    if ($Type -and $MAIN.APIs.$Type.Headers) {
        foreach ($property in $($MAIN.APIs.$Type.Headers | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name)) {
            if ($Config._API.headers.$property) {
                $Config._API.headers.$property = $MAIN.APIs.$Type.Headers.$property
            } else {
                $Config._API.headers.add($property, $MAIN.APIs.$Type.Headers)
            }
        }
    }
}