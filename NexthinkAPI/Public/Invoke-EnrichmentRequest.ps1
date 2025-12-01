function Invoke-EnrichmentRequest {
    <#
    .SYNOPSIS
        Enriches Nexthink objects via the Enrichment API.
    .DESCRIPTION
        Sends one enrichment payload (or an array of payloads) to the Nexthink
        Enrichment API endpoint using a PUT-style call.
    .INPUTS
        None. This does not accept pipeline input.
    .OUTPUTS
        The response object returned by Invoke-NxtApi.
    .NOTES
        Expects a structured object/hashtable representing the enrichment payload,
        not a pre-serialized JSON string.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        # Enrichment payload (PSCustomObject / hashtable / array of such objects)
        [Parameter(Mandatory = $true)]
        [Alias('Body')]
        [ValidateScript({
            if ($null -eq $_) {
                throw "Enrichment object cannot be null."
            }

            if ($_ -is [string]) {
                throw "Enrichment must be an object (hashtable/PSCustomObject/array), not a JSON string. Pass the structured data and let the function handle JSON serialization."
            }

            # Allow PSCustomObject, hashtable, arrays of objects, etc.
            $true
        })]
        [object]$Enrichment
    )

    $apiType = 'Enrichment'

    try {
        # Serialize enrichment payload
        $bodyJson = $Enrichment | ConvertTo-Json -Depth 8 -Compress

        if ([string]::IsNullOrWhiteSpace($bodyJson) -or $bodyJson -eq '{}' -or $bodyJson -eq '[]') {
            throw "Enrichment payload serialized to an empty JSON object/array. Check the Enrichment data structure."
        }

        Write-CustomLog -Message "Enrichment Request Body: $bodyJson" -Severity 'DEBUG'
    }
    catch {
        $msg = "Failed to serialize Enrichment payload to JSON. Details: $($_.Exception.Message)"
        Write-CustomLog -Message $msg -Severity 'ERROR'
        throw $msg
    }

    return Invoke-NxtApi -Type $apiType -Body $bodyJson -ReturnResponse
}
