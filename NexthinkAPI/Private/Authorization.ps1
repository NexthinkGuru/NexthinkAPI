function Get-ClientCredentials {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Target
    )

    # Retrieve stored credentials from Windows Credential Manager
    try {
        $storedCredentials = Get-StoredCredential -Target $Target -ErrorAction Stop
    }
    catch {
        $message = "Failed to read stored credentials for target '$Target'. $($_.Exception.Message)"
        Write-CustomLog -Message $message -Severity 'ERROR'
        throw $message
    }

    if (-not $storedCredentials -or
        [string]::IsNullOrWhiteSpace($storedCredentials.UserName) -or
        $null -eq $storedCredentials.Password) {

        $message = "Credentials not found or incomplete for target '$Target'."
        Write-CustomLog -Message $message -Severity 'ERROR'
        throw $message
    }

    # Convert SecureString password to plain text
    $bstr = [IntPtr]::Zero
    try {
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($storedCredentials.Password)
        $plainSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($bstr)
    }
    finally { # Zero and free the unmanaged buffer
        if ($bstr -ne [IntPtr]::Zero) {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }

    [pscustomobject]@{
        ClientId     = $storedCredentials.UserName
        ClientSecret = $plainSecret
    }
}

function Get-Jwt {
    [CmdletBinding()]
    param ()

    $uri = "https://{0}-login.{1}.nexthink.cloud{2}" -f `
        $Config.NexthinkAPI.InstanceName, `
        $Config.NexthinkAPI.Region, `
        $MAIN.APIs.OAuth.Path

    Write-CustomLog -Message "Uri for JWT: $uri" -Severity 'DEBUG'
    Write-CustomLog -Message "Credential Target: $($Config.NexthinkAPI.OAuthCredentialEntry)" -Severity 'DEBUG'

    $oldProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    try {
        $credentials = Get-ClientCredentials -Target $Config.NexthinkAPI.OAuthCredentialEntry

        $basicHeader = Get-StringAsBase64 -InputString ("{0}:{1}" -f $credentials.ClientId, $credentials.ClientSecret)

        $headers = $Config._API.headers
        $headers['Authorization'] = "Basic $basicHeader"

        $body = @{
            grant_type = 'client_credentials'
            scope      = 'service:integration'
        }

        $parameters = @{
            Uri             = $uri
            Method          = 'POST'
            Headers         = $headers
            Body            = $body
            ContentType     = 'application/x-www-form-urlencoded'
            UseBasicParsing = $true
            ErrorAction     = 'Stop'
        }

        $response = Invoke-WebRequest @parameters

        Remove-Variable credentials, basicHeader -Force -ErrorAction SilentlyContinue

        if ($response.StatusCode -ne 200) {
            $message = "Error Code: $($response.StatusCode). Unable to access $uri endpoint."
            Write-CustomLog -Message $message -Severity 'ERROR'
            throw $message
        }

        $parsedResponse = $response.Content | ConvertFrom-Json
        $tokenDate      = [DateTime]$response.Headers.Date
        $expiresUtc     = $tokenDate.AddSeconds($parsedResponse.expires_in)

        Write-CustomLog -Message ("Retrieved JWT. Expires at {0:u}" -f $expiresUtc) -Severity 'DEBUG'

        [pscustomobject]@{
            token   = $parsedResponse.access_token
            expires = $expiresUtc
        }
    }
    catch [System.Net.WebException] {
        $ex = $_.Exception
        $statusCode = $null

        if ($ex.Response -and $ex.Response -is [System.Net.HttpWebResponse]) {
            $statusCode = [int]$ex.Response.StatusCode
        }

        if ($statusCode -eq 407) {
            $message = @"
Proxy authentication required when calling $uri.
If your environment uses an authenticating proxy, set `"Proxy.UseDefaultCredentials`" to true in config.json
and re-run Initialize-NexthinkAPI so the module can send default credentials to the proxy.
"@.Trim()
        }
        else {
            $message = "Unable to access $uri endpoint. Details: $($ex.Message)"
        }

        Write-CustomLog -Message $message -Severity 'ERROR'
        throw $message
    }
    catch [System.IO.IOException] {
        $message = "Unable to access $uri endpoint due to an I/O error. Details: $($_.Exception.Message)"
        Write-CustomLog -Message $message -Severity 'ERROR'
        throw $message
    }
    catch {
        $message = "An unexpected error occurred while requesting JWT. Details: $($_.Exception.Message)"
        Write-CustomLog -Message $message -Severity 'ERROR'
        throw $message
    }
    finally {
        $ProgressPreference = $oldProgress
    }
}

function Set-Headers {
    [CmdletBinding()]
    param ()

    if (-not $script:Config -or -not $Config._API) {
        throw "Nexthink API is not initialized. Call 'Initialize-NexthinkAPI' before running any functions"
    }

    if (-not $Config._API.headers) {
        throw "Nexthink API headers not initialized. 'Initialize-NexthinkAPI' did not complete successfully."
    }

    $now = Get-Date

    # Refresh if missing or expiring within 1 minute
    if (-not $Config._API.expires -or $Config._API.expires.AddMinutes(1) -lt $now) {
        # Obtain new JWT
        Write-CustomLog -Message "JWT is missing or expiring soon. Obtaining new token." -Severity 'DEBUG'
        $localToken = Get-Jwt

        $Config._API.expires = $localToken.expires
        $Config._API.headers['Authorization'] = "Bearer $($localToken.token)"
    }
}

function Set-SecurityProtocol {
    [CmdletBinding()]
    param ()

    $TLS_12 = 3072
    $TLS_13 = 12288

    # Always enable TLS 1.2
    $protocols = [enum]::ToObject([Net.SecurityProtocolType], $TLS_12)

    # Try to add TLS 1.3 if the runtime supports it
    try {
        $protocols = $protocols -bor [enum]::ToObject([Net.SecurityProtocolType], $TLS_13)
    }
    catch {
        # TLS 1.3 not available on this runtime – ignore
    }

    [Net.ServicePointManager]::SecurityProtocol = $protocols

    # Proxy handling driven by config
    $proxyConfig = $Config.Proxy

    if ($proxyConfig -and $proxyConfig.UseSystemProxy) {
        $proxy = [System.Net.WebRequest]::GetSystemWebProxy()

        if ($proxy) {
            if ($proxyConfig.UseDefaultCredentials) {
                # Opt-in only; otherwise we don't send creds to the proxy
                $proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
            }

            [System.Net.WebRequest]::DefaultWebProxy = $proxy
        }
    }
    # else: leave DefaultWebProxy as-is (no proxy or whatever the process already has)
}

function Get-StringAsBase64 ([string]$InputString) {
    [CmdletBinding()]
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
    $EncodedText = [Convert]::ToBase64String($Bytes)
    return $EncodedText
}
