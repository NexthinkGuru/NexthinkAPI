function Invoke-NqlQuery {
    <#
    .SYNOPSIS
        Triggers NQL Query execution
    .DESCRIPTION
        Triggers the execution of an NQL query, returning up to 1000 results
    .EXAMPLE
    PS> [PSCustomObject]$myQueryOutput = Invoke-NqlQuery -QueryId "#my_nql_test_query"
    .EXAMPLE
    PS> [PSCustomObject]$myQueryData = Invoke-NqlQuery -QueryId "#my_nql_test_query" -DataOnly
    .INPUTS
        Query ID: An identifier for the query​. Once defined this can no longer be changed.
        Parameters: Optional hashtable of parameters used by the query.
    .OUTPUTS
        [PSCustomObject]
            queryId             string                  Identifier of the executed query
            executedQuery       string                  Final query executed with the parameters replaced
            rows                integer<int32>          Number of rows returned
            executionDateTime   DateTime                Date and time of the execution (in Nexthink Server timezone)
            data                array[PSCustomObject]   Array of PSCustomObjects containing the data rows (only if -DataOnly is not used)
    .NOTES
        Times out after 5 seconds.
    #>
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if (-not (Test-IsValidNqlId $_)) {
                throw "Invalid NQL Query ID: $_"
            }
            $true
        })]
        [string]$QueryId,

        [parameter(Mandatory=$false)]
        [hashtable]$Parameters,

        [parameter(Mandatory=$false)]
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
    } else {
        # Modify response with proper datetime field for execution
        try {
            $local:executionDateTime = [DateTime]::ParseExact($ApiResponse.executionDateTime,"yyyy-MM-ddTHH:mm:ss",$null)
            $ApiResponse.executionDateTime = $local:executionDateTime
        }
        catch {
            Write-CustomLog -Message "Failed to parse executionDateTime: $($_.Exception.Message)" -Severity "WARNING"
        }
        return $ApiResponse
    }
}