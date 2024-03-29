﻿function Get-Jwt {
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

    $uri = $Config._API.BASE + $MAIN.APIs.OAUTH.uri
    Write-CustomLog -Message "Uri for JWT: $uri" -Severity "DEBUG"

    # Invoke-WebRequests usually displays a progress bar. The $ProgressPreference variable determines whether this is displayed (default value = Continue)
    $ProgressPreference = 'SilentlyContinue'
    try {
        Write-CustomLog "Credential Target: $($Config.NexthinkAPI.OAuthCredentialEntry)" -Severity "DEBUG"
        $credentials = Get-ClientCredentials -Target $Config.NexthinkAPI.OAuthCredentialEntry

        $basicHeader = Get-StringAsBase64 -InputString "$($credentials.clientId):$($credentials.clientSecret)"
        $headers = $BASE_API.headers
        $headers.Authorization = "Basic " + $basicHeader

        $response = Invoke-WebRequest -Uri $uri -Method 'POST' -Headers $headers -UseBasicParsing

        Remove-Variable credentials,basicHeader -Force -ErrorAction SilentlyContinue
        
        if ($response.StatusCode -ne '200') {
            Write-Warning "Error Code: $($response.StatusCode)"
            $message = "Error Code: $($response.StatusCode).  Unable to access $($uri) Endpoint. Details: $($_.Exception.Message)"
            Write-CustomLog -Message $message -Severity 'ERROR'
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