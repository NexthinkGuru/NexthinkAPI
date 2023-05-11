function Get-Jwt {
    <#
    .SYNOPSIS
        Retrieves the JWT from the API
    .DESCRIPTION
        Logs into the API Token endpoint and gets the JWT using the oauth credentials
    .INPUTS
        None. This does not accept pipeline input.
    .OUTPUTS
        token & expiration of token
    .NOTES
        This function is only meant for use within other Nexthink functions.
    #>
    [CmdletBinding()]
    param ()

    $uri = $CONFIG._API.BASE + $MAIN.APIs.OAUTH.uri

    # Invoke-WebRequests usually displays a progress bar. The $ProgressPreference variable determines whether this is displayed (default value = Continue)
    $ProgressPreference = 'SilentlyContinue'  
    try {
        Write-CustomLog "Getting Credentials for $($CONFIG.NexthinkAPI.OAuthCredentialEntry) " -Severity "DEBUG"
        $credentials = Get-ClientCredentials -Target $CONFIG.NexthinkAPI.OAuthCredentialEntry

        $basicHeader = Get-StringAsBase64 -InputString "$($credentials.clientId):$($credentials.clientSecret)"
        $headers = $BASE_API.headers
        $headers.Authorization = "Basic " + $basicHeader

        $response = Invoke-WebRequest -Uri $uri -Method 'POST' -Headers $headers -UseBasicParsing
        if ($response.StatusCode -ne '200') {
            $message = "Error sending request to get the JWT token with status code: $($response.StatusCode)"
            Write-CustomLog -Message Write-CustomLog -Message "Unable to access $($uri) Endpoint. Details: $($_.Exception.Message)" -Severity 'ERROR' -Severity 'ERROR'
            throw $message
        }

        $parsedResponse = ConvertFrom-Json $([String]::new($response.Content))
        $tokenDate = [DateTime]$response.Headers.Date
        Write-CustomLog -Message "Retrieved JWT: $parsedResponse" -Severity 'DEBUG'
        @{token = $parsedResponse.access_token; expires = $tokenDate.AddSeconds($parsedResponse.expires_in)}
    } catch [net.webexception], [io.ioexception] {
        $message = "Unable to access $($uri) Endpoint. Details: $($_.Exception.Message)"
        Write-CustomLog -Message $message -Severity 'ERROR'
        throw $message
    } catch {
        $message = "An error occurred that could not be resolved. Details: $($_.Exception.Message)"
        Write-CustomLog -Message $message -Severity 'ERROR'
        throw $message
    }
    $ProgressPreference = 'Continue'
}