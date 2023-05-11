function Invoke-RemoteAction {
    <#
    .SYNOPSIS
        Triggers RA for devices
    .DESCRIPTION
        Triggers the execution of Remote Actions for 1 or more devivces
    .INPUTS
        RA ID
        List of device UID's
        Optional RA Parameters
        This does not accept pipeline input.
    .OUTPUTS
        Object. 
    .NOTESn
    #>
    [CmdletBinding()]
    param(
        # path of the request
        $path=$API_PATHS.RA_EXEC,

        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$remoteActionId,

        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('DeviceIdList')]
        [Array]$devices,
        
        [Alias('Expires')]
        [Int]$expiresInMinutes = 10800,
        
        [parameter(Mandatory=$false)]
        [hashtable]$Parameters
    )

    $uri = $CONFIG._API.BASE + $path

    $body = @{
        remoteActionId = $remoteActionId
        devices = $deviceIdList
    }
    # Build Add any optional dynamic parameters for the RA
    if (($null -ne $Parameters) -and ($Parameters.count -ge 1)) {
        $body.Add('params', $Parameters)
    }
    $bodyJson = $body | ConvertTo-Json -Depth 4

    Set-Jwt

    $invokeParams = @{
        Uri = $uri
        Method = 'POST'
        Headers = $CONFIG._API.headers
        ContentType = 'application/json'
        Body = $bodyJson
    }

    try {
        $response = Invoke-RestMethod @invokeParams
        $response
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
}