function Invoke-EnrichmentRequest {
    <#
    .SYNOPSIS
        Enriches Nexthink Objects
    .DESCRIPTION
        PUTs data to the Nexthink Enrichment API endpoint for updating.
    .INPUTS
        None. This does not accept pipeline input.
    .OUTPUTS
        Object. 
    .NOTES
    #>
    [CmdletBinding()]
    param(
        # path of the request
        $path=$API_PATHS.ENRICHMENT,

        # the body of the request. This can be either json or a formatted form-data
        [parameter(Mandatory=$true)]
        [Alias('json','Enrichment')]
        $body
    )

    $uri = $CONFIG._API.BASE + $path
    $bodyJson = $body | ConvertTo-Json -Depth 8 -Compress

    Set-Jwt

    $invokeParams = @{
        Uri = $uri
        Method = 'POST'
        Headers = $CONFIG._API.headers
        ContentType = 'application/json'
        Body = $bodyJson
    }

    try {
        Write-CustomLog -Message "Invoking Enrichment: $Uri" -Severity "DEBUG"
        Write-CustomLog -Message "Enrichment Body: $BodyJson" -Severity "DEBUG"
        $response = Invoke-RestMethod @invokeParams
        if ($response.status -ne 'success') {
            throw $response.errors
        }
        Write-CustomLog -Message "Response:$response " -Severity "DEBUG"
    } catch [System.Net.WebException] {
        # A web error has occurred
        $StatusCode = $_.Exception.Response.StatusCode.Value__
        $Headerdetails = $_.Exception.Response.Headers
        $ThisException = $_.Exception
        $NexthinkMsgJson = $_
        $NexthinkMsg = $NexthinkMsgJson | ConvertFrom-Json
    
        switch ($StatusCode)
        {
            400 {
                # Bad Request
                $OutputObject = [PSCustomObject]@{
                    error = 400
                    'Path&Query' = $thisException.Response.ResponseUri.PathAndQuery
                    description = 'Bad request - invalid enrichment.'
                    Errors = $($NexthinkMsg.errors)
                }
                Write-CustomLog -Message $OutputObject.description -Severity 'ERROR'
                throw $OutputObject
            }

            401 {
                # Authentication Failure
                $OutputObject = [PSCustomObject]@{
                    error = 401
                    'Path&Query' = $thisException.Response.ResponseUri.PathAndQuery
                    description = "Unauthorized - invalid authentication credentials"
                    NexthinkCode = $($NexthinkMsg.code)
                    message = $($NexthinkMsg.message)
                }
                Write-CustomLog -Message $($OutputObject.message) -Severity 'ERROR'
                throw $OutputObject
            }

            403 {
                # Forbidden
                $OutputObject = [PSCustomObject]@{
                    error = 403
                    'Path&Query' = $thisException.Response.ResponseUri.PathAndQuery
                    description = "Forbidden - no permission to trigger enrichment"
                    NexthinkCode = $($NexthinkMsg.code)
                    message = $($NexthinkMsg.message)
                }
                Write-CustomLog -Message $($OutputObject.message) -Severity 'ERROR'
                throw $OutputObject
            }

            # 429 {
            #     # Too many requests
            #     $WaitForSeconds = $Headerdetails['Retry-After']
            #     Write-Verbose "Waiting for $WaitForSeconds seconds..."
            #     Start-Sleep -second $WaitForSeconds
            #     $path = $ThisException.Response.ResponseUri.PathAndQuery.Replace("/api/v2/","") 
            #     Invoke-APIQuery -path $path -field $field -system $System                
            # }

            # 500 {
            #     $OutputObject = [PSCustomObject]@{
            #         error = 500
            #         'Path&Query' = $thisException.Response.ResponseUri.PathAndQuery
            #         description = "A Server Error occurred requesting '$uri'. Please verify the input fields before contacting Nexthink Support."
            #     }                
            #     throw $OutputObject                     
            # }

            default {
                throw
            }
        }

    } catch {
        throw $_
    }
}