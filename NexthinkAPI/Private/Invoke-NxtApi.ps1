function Invoke-NxtApi {
    [OutputType([PSCustomObject])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$Type,
        [String]$Body = $null,
        [String]$Query = $null,
        [switch]$ReturnResponse
    )

    $uri = $CONFIG._API.BASE + $MAIN.APIs.$ApiType.uri + $Query

    $method = $MAIN.APIs.$ApiType.Method

    # Ensure we have a JWT that's valid with headers set
    Set-Headers

    #     $CONFIG._API.headers.'x-enrichment-trace-id' = ([guid]::NewGuid()).Guid

    # Set base IWR Parameters
    $invokeParams = @{
        Uri = $uri
        Method = $method
        Headers = $CONFIG._API.headers
        ContentType = 'application/json'
    }

    # Add a body if we have one
    if ($null -ne $Body -and '' -ne $Body) {
        $invokeParams.Add('Body', $Body)
        Write-Verbose "Request: $Body"
        Write-CustomLog "Request: $Body" -Severity "DEBUG"
    }

    try {
        $response = Invoke-RestMethod @invokeParams
        $responseJson = $response | ConvertTo-Json -Compress
        Write-CustomLog -Message "Response: $responseJson" -Severity "DEBUG"
        Write-Verbose "Response: $responseJson"

    } catch [System.Net.WebException] {
        # A web error has occurred
        $StatusCode = $_.Exception.Response.StatusCode.Value__
        $ThisException = $_.Exception
        $NexthinkMsg = $_ | ConvertFrom-Json
        $Message = $_.ErrorDetails.Message | ConvertFrom-Json
        $matchCode = $MAIN_CONFIG.ResponseCodes.$Type | where-Object {$_.Code -eq $StatusCode}

        $OutputObject = [PSCustomObject]@{
            error = $StatusCode
            'Path&Query' = $thisException.Response.ResponseUri.PathAndQuery
            description = $matchCode.Message
            NexthinkCode = $($NexthinkMsg.code)
            Errors = $($NexthinkMsg.errors)
        }

        if ($null -ne $Message -and $null -eq $NexthinkMsg) {
            $OutputObject.Errors = $Message._embedded.errors.message
        } 
        Write-CustomLog -Message $($OutputObject) -Severity 'ERROR'
        throw $OutputObject
    } catch {
        throw $_
    }

    if ($ReturnResponse) {
        return $response
    } 
}