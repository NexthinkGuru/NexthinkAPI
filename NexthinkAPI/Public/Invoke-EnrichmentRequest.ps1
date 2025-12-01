function Invoke-EnrichmentRequest {
<#
.SYNOPSIS
    Sends enrichment payloads to the Nexthink Enrichment API.

.DESCRIPTION
    Submits one or more enrichment objects to the Nexthink Enrichment API using
    a JSON payload. The function expects structured PowerShell objects
    (hashtables / PSCustomObjects / arrays of such objects) and handles JSON
    serialization internally.

    Typical usage is to build the payload with helper functions such as
    New-SingleFieldEnrichment and pass the resulting object to this function.

.PARAMETER Enrichment
    The enrichment payload to send to the Nexthink Enrichment API.

    Requirements:
      - Must NOT be $null.
      - Must NOT be a string (JSON or otherwise). Callers should pass objects,
        not pre-serialized JSON.
      - May be:
          • A single PSCustomObject
          • A hashtable
          • An array of PSCustomObjects/hashtables

    The parameter is aliased as -Body for convenience.

.INPUTS
    None. This function does not accept pipeline input.

.OUTPUTS
    [object]

    Returns the response object from Invoke-NxtApi for the Enrichment API call.

.EXAMPLE
    $enrichment = New-SingleFieldEnrichment `
        -FieldName  'device.#location' `
        -ObjectName 'device.name' `
        -ObjectValues @{ 'LAPTOP-001' = 'New York' }

    Invoke-EnrichmentRequest -Enrichment $enrichment

    Builds a single-field enrichment payload and sends it to the Nexthink
    Enrichment API.

.NOTES
    - This function performs JSON serialization internally via ConvertTo-Json
      with a depth of 8 and compression enabled.
    - If the serialized JSON is empty ("{}" or "[]"), the function throws to
      prevent sending invalid enrichment requests.
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
