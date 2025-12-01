function Invoke-NxtApi {
    [OutputType([PSCustomObject])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$Type,
        [String]$Body = $null,
        [String]$Query = $null,
        [switch]$ReturnResponse
    )

    # Query is a possible code injection after the base path - need to fix this later
    $uri = $Config._API.BASE + $MAIN.APIs.$Type.Path + $Query
    Write-CustomLog -Message "URI: $uri" -Severity "DEBUG"
    $method = $MAIN.APIs.$Type.Method

    Set-Headers  # Ensure we have a valid JWT

    # Set base Parameters
    $invokeParams = @{
        Uri         = $uri
        Method      = $method
        Headers     = $Config._API.headers
    }
    if ($method -in @('POST','PUT','PATCH')) {
        $invokeParams.Add('ContentType', 'application/json')
    }
    $msgParameters = $invokeParams.GetEnumerator() | ForEach-Object { "{0}:{1}" -f $_.key, ($_.value | Out-String) }
    Write-CustomLog "Invoke Web Request Params: `n$msgParameters" -Severity "DEBUG"

    # Add a body if we have one
    if ($null -ne $Body -and '' -ne $Body) {
        $invokeParams.Add('Body', $Body)
        Write-CustomLog "Request Body: `n$Body" -Severity "DEBUG"
    }

    try {
        $response = Invoke-RestMethod @invokeParams
        $responseJson = $response | ConvertTo-Json -Compress
        Write-CustomLog -Message "Response: $responseJson" -Severity "DEBUG"
    }
    catch [System.Net.WebException] {
        # A web error has occurred
        $statusCode = $_.Exception.Response.statusCode.Value__
        $errorDetails = $_.ErrorDetails.Message | ConvertFrom-Json
        $errorCode = $errorDetails.code
        $errorMessage = $errorDetails.message

        $lookupType = $Type
        if ($null -eq $MAIN.ResponseCodes.$Type) {
            $lookupType = $Type -replace "_.*$"
        }

        # Start error message
        $message = @()
        switch ($statusCode) {
            400 {
                $message += "Bad request(400) - Invalid request"
                $message += ''
                if ($null -eq $errorCode -and $errorDetails.status -eq "error") {
                    $message += "Many errors presented"
                    $message += "--> Json list of errors"
                    $message += ($errrorDetails.errors | ConvertTo-Json -Depth 8 -Compress | out-string)
                }
                else {
                    $message += "--> $errorCode"
                }
            }
            401 {
                $message += "Unauthorized(401) - No valid authentication credentials."
                $message += ''
                $message += '--> Ensure these credentials have access to the requested action'
            }
            403 {
                $message += "No Permission(403) - No permission to perform requested action."
                $message += ''
                $message += "--> Please verify the credentials have access to the $lookupType API"
            }
            404 {
                $message += "Page Not Found (404)"
                $message += ''
                $message += "--> The URI, $uri, doesn't work."
                $message += "--> Either the instance, api's, or this module has a defect"
            }
            429 {
                # Too may requests, pause and repeat?!?
                $retryAfter = $_.Exception.Response.Headers.'Retry-After'
                $message += "Slow Down, Speed Racer!!"
                $message += ''
                $message += "Retry After $retryAfter"
                #When throttling occurs, the API returns the HTTP status code 429, and the requests fail.
                #It is best practice to catch 429 responses in your code and retry the request after a suitable waiting period.
                #Refer to the value specified in the Retry-After header from the response.
            }
            Default {
                $responseCodes = $MAIN.ResponseCodes.$lookupType
                $matchedCode = $responseCodes | where-Object { $_.Code -eq $statusCode }
                if ($null -ne $matchedCode) {
                    $message += $matchedCode.Status
                    $message += $matchedCode.message
                    if ($null -ne $matchedCode.keys) {
                        $matchedKeys = $($matchedCode.keys).split(',')
                        foreach ($key in $matchedKeys) {
                            $subMessage = $errorMessage.$key
                            if ($subMessage.gettype().Name -ne "String") {
                                $subMessage = $errorMessage.$key | ConvertTo-Json -compress
                            }
                            $message += "--> $subMessage"
                        }
                    }
                }
                else {
                    $message += "Error: $errorCode"
                }
            }
        }

        $message += "--> Error Message:"
        $message += "Message: $errorMessage"

        Write-Error -message ($message | out-string) -ErrorId $errorCode
        Write-CustomLog -Message ($message | out-string) -Severity 'ERROR'

        throw $($errorCode -as [int])
    }
    catch {
        throw $_
    }

    if ($ReturnResponse) {
        return $response
    }
}