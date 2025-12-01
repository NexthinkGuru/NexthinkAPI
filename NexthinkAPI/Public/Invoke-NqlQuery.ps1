function Invoke-NqlQuery {
    <#
.SYNOPSIS
    Executes a Nexthink NQL query.

.DESCRIPTION
    Executes an NQL query by its QueryId and optionally applies parameters.
    Returns the full query execution result or, when -DataOnly is specified,
    returns only the data rows.

    The query execution is subject to Nexthink API limits, including:
      • Up to 1000 returned rows
      • Server-side timeout of ~5 seconds (enforced by Nexthink)

.PARAMETER QueryId
    The NQL Query Identifier to execute.

    Must be a valid NQL ID (e.g., "#my_query_id") and is validated using
    Test-IsValidNqlId.

.PARAMETER Parameters
    Optional hashtable of key/value pairs representing query parameters.
    Keys must match the parameter names defined inside the target query.

.PARAMETER DataOnly
    Switch that returns only the resulting data rows rather than the full
    execution response object.

.INPUTS
    None. This function does not accept pipeline input.

.OUTPUTS
    When -DataOnly is NOT used:
        [PSCustomObject]
            queryId             string
            executedQuery       string
            rows                int
            executionDateTime   DateTime     (converted to local .NET DateTime)
            data                PSCustomObject[]

    When -DataOnly *is* used:
        PSCustomObject[]        (the 'data' array only)

.EXAMPLE
    $result = Invoke-NqlQuery -QueryId "#my_nql_test_query"

    Executes the specified query and returns the full response object.

.EXAMPLE
    $rows = Invoke-NqlQuery -QueryId "#my_nql_test_query" -DataOnly

    Executes the query and returns only the data rows.

.NOTES
    Nexthink enforces a ~5-second timeout on NQL query execution.
#>
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                if (-not (Test-IsValidNqlId $_)) {
                    throw "Invalid NQL Query ID: $_"
                }
                $true
            })]
        [string]$QueryId,

        [parameter(Mandatory = $false)]
        [hashtable]$Parameters,

        [parameter(Mandatory = $false)]
        [switch]$DataOnly

    )
    $APITYPE = 'NQL'

    ## Build the body for the NQL Query execution
    $body = @{ queryId = $QueryId }
    # add any optional dynamic parameters
    if (($null -ne $Parameters) -and ($Parameters.count -ge 1)) {
        $body.Add('parameters', $Parameters)
    }
    $bodyJson = $body | ConvertTo-Json -Depth 4

    $ApiResponse = Invoke-NxtApi -Type $APITYPE -Body $bodyJson -ReturnResponse

    if ($DataOnly) {
        return $ApiResponse.data
    }
    else {
        # Modify response with proper datetime field for execution
        try {
            $local:executionDateTime = [DateTime]::ParseExact($ApiResponse.executionDateTime, "yyyy-MM-ddTHH:mm:ss", $null)
            $ApiResponse.executionDateTime = $local:executionDateTime
        }
        catch {
            Write-CustomLog -Message "Failed to parse executionDateTime: $($_.Exception.Message)" -Severity "WARNING"
        }
        return $ApiResponse
    }
}