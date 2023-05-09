function Invoke-ListRemoteActions {
    <#
    .SYNOPSIS
        Lists available Remote Actions
    .DESCRIPTION
        Returns an object of RA's enabled for API Consumption
    .INPUTS
        Optional Remote Action ID. This does not accept pipeline input.
    .OUTPUTS
        Object.
    .NOTES
        ?hasScriptWindows=true&hasScriptMacOs=false
    #>
    [CmdletBinding()]
    param(
        # path of the request
        $path=$API_PATHS.RA_LIST,

        [parameter(Mandatory=$false)]
        [Alias('nqlId')]
        [string]$remoteActionId
    )

    $uri = $CONFIG._API.BASE + $path
    if ($null -ne $remoteActionId) {
        $remoteActionIdEncoded = [System.Web.HttpUtility]::UrlEncode($remoteActionId)
        $uri = -join ($uri,$API_PATHS.RA_DETAILS,$remoteActionIdEncoded)
    }

    Set-Jwt

    $invokeParams = @{
        Uri = $uri
        Method = 'GET'
        Headers = $CONFIG._API.headers
        ContentType = 'application/json'
    }

    try {
        $response = Invoke-RestMethod @invokeParams
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
                throw $OutputObject
            }

            default {
                throw
            }
        }
    } catch {
        throw $_
    }
    
    # Process through the responses, only returning the ones we want.
    if ($null -ne $remoteActionId) {
        foreach ($RA in $response) {
            if ($RA.targeting.apiEnabled) { $RA }
        } 
    } else { $response }
}