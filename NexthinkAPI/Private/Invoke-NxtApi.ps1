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

    $uri = $CONFIG._API.BASE + $MAIN.APIs.$Type.uri + $Query

    $method = $MAIN.APIs.$Type.Method

    # Ensure we have a JWT that's valid with headers set
    Set-Headers

    # Set base IWR Parameters
    $invokeParams = @{
        Uri = $uri
        Method = $method
        Headers = $CONFIG._API.headers
        ContentType = 'application/json'
    }
    $msg = "Params: $($invokeParams.GetEnumerator() | ForEach-Object { '{0}:{1},' -f $_.key, $_.value })"
    Write-Verbose $msg
    Write-CustomLog $msg -Severity "DEBUG"

    # Add a body if we have one
    if ($null -ne $Body -and '' -ne $Body) {
        $invokeParams.Add('Body', $Body)
        $msg = "Request: $Body"
        Write-Verbose $msg
        Write-CustomLog $msg -Severity "DEBUG"
    }

    try {
        $response = Invoke-RestMethod @invokeParams
        $responseJson = $response | ConvertTo-Json -Compress
        Write-CustomLog -Message "Response: $responseJson" -Severity "DEBUG"
        Write-Verbose "Response: $responseJson"

        if ($response.StatusCode -ne 200) {}

    } catch [System.Net.WebException] {
        # A web error has occurred
        $statusCode = $_.Exception.Response.statusCode.Value__
        $errorMessage = $_.ErrorDetails.Message | ConvertFrom-Json

        if ($null -eq $MAIN.ResponseCodes.$Type) {
            $lookupType = $Type -replace "_.*$"
        }
        else {
            $lookupType = $Type
        }

        $responseCodes = $MAIN.ResponseCodes.$lookupType
        $matchedCode = $responseCodes | where-Object {$_.Code -eq $statusCode}
        if ($null -ne $matchedCode.keys) {
            $matchedKeys = $($matchedCode.keys).split(',')
            foreach ($key in $matchedKeys) {
                $subMessage = $errorMessage.$key
                if ($subMessage.gettype().Name -ne "String") {
                    $subMessage = $errorMessage.$key | ConvertTo-Json -compress
                }
                $message = "$key : $subMessage"
                Write-Warning $message
                Write-CustomLog -Message $message -Severity 'ERROR'
            }
        }
        
        $message = "Error $statusCode - $($matchedCode.Message)"
        Write-CustomLog -Message $message -Severity 'ERROR'
        throw $message
    } catch {
        throw $_
    }

    if ($ReturnResponse) {
        return $response
    } 
}