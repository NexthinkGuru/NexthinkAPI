function Invoke-NqlQuery {
    <#
    .SYNOPSIS
        Triggers NQL Query execution api v2
    .DESCRIPTION
        Triggers the execution of an NQL query, returning up to 1000 results
    .EXAMPLE
    PS> [PSCustomObject]$myQueryOutput = Invoke-NqlQuery -QueryId "#my_nql_test_query"
    .EXAMPLE
    PS> [PSCustomObject]$myQueryData =nvoke-NqlQuery -QueryId "#my_nql_test_query" -DataOnly
    .INPUTS
        Query ID: An identifier for the query​. Once defined this can no longer be changed.
        Parameters: Optional hashtable of parameters used by the query.
    .OUTPUTS
        [PSCustomObject]
            queryId             string          Identifier of the executed query
            executedQuery       string          NQL query executed with any parameters replaced
            rows                int32           Number of rows returned
            executionDateTime   DateTime        Date and time of the execution
            data                arraylist       Arraylist of PS Custom objects for each row of data output
        
    .NOTES
        Times out after 5 seconds.
        Using the v2 API

    #>
    [CmdletBinding()]
    param(
        [ValidatePattern('^#[A-z0-9_]{2,255}$')]
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$QueryId,
                
        [parameter(Mandatory=$false)]
        [hashtable]$Parameters,

        [parameter(Mandatory=$false)]
        [Alias('d')]
        [switch]$DataOnly

    )
    $APITYPE = 'NQL'
    if ($DataOnly) { $APITYPE += '_DataOnly' }

    $body = @{ queryId = $QueryId }

    # Add optional dynamic parameters for the RA
    if (($null -ne $Parameters) -and ($Parameters.count -ge 1)) {
        $body.Add('parameters', $Parameters)
    }

    $bodyJson = $body | ConvertTo-Json -Depth 4
    
    $ApiResponse = Invoke-NxtApi -Type $APITYPE -Body $bodyJson -ReturnResponse

    if ($DataOnly) {
        return [System.Collections.ArrayList]$ApiResponse
    } else {
        # perform some data re-formatting
        $ApiResponse.executionDateTime = [datetime]::ParseExact($ApiResponse.executionDateTime, "yyyy-M-dTH:m:s", $null)
        $ApiResponse.data = [System.Collections.ArrayList]$ApiResponse.data
        return $ApiResponse
    }
}