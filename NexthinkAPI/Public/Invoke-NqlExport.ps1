function Invoke-NqlExport {
    <#
    .SYNOPSIS
        Triggers NQL Query Export 
    .DESCRIPTION
        Triggers the execution of an NQL query, returning up to 1M results
    .EXAMPLE
    PS> [PSCustomObject]$myQueryOutput = Invoke-NqlExport -QueryId "#my_nql_test_query"
    .EXAMPLE
    PS> [PSCustomObject]$myQueryData = Invoke-NqlExport -QueryId "#my_nql_test_query" -DataOnly
    .INPUTS
        Query ID: An identifier for the query​. Once defined this can no longer be changed.
        Parameters: Optional hashtable of parameters used by the query.
    .OUTPUTS
        [PSCustomObject]
            queryId             string          Identifier of the executed query
            executedQuery       string          Final query executed with the parameters replaced
            rows                integer<int64>  Number of rows returned
            executionDateTime   DateTime        Date and time of the execution
            headers             array[string]   Ordered list with the headers of the returned fields
            data                array[array]    List of row with the data returned by the query execution object
        
    .NOTES

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
    $APITYPE = 'NQL_Export'

    $query = "?queryId=" + [System.Web.HttpUtility]::UrlEncode($QueryId)

    if (($null -ne $Parameters) -and ($Parameters.count -ge 1)) {
        foreach ($key in $Parameters.keys) {
            $query += "&$key=" + [System.Web.HttpUtility]::UrlEncode($Parameters[$key])
        }
    }
 
    # get the export ID 
    $ApiResponse = Invoke-NxtApi -Type $APITYPE -Query $query -ReturnResponse
    if ($ApiResponse.exportId) {
        $APITYPE = 'NQL_Export_Status'
        
        $statusResponse = Invoke-NxtApi -Type 
    }
    if ($DataOnly) {
        return [System.Collections.ArrayList]$ApiResponse.data
    } else {
        # Modify response with proper datetime field for execution
        $ApiResponse.executionDateTime = [datetime]::ParseExact($tmpDT, "yyyy-M-dTH:m:s", $null)
        $ApiResponse.data = [System.Collections.ArrayList]$ApiResponse.data
        return $ApiResponse
    }
}