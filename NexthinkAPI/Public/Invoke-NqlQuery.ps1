function Invoke-NqlQuery {
    <#
    .SYNOPSIS
        Triggers NQL Query creation
    .DESCRIPTION
        Triggers the execution of an NQL query, returning up to 100 results
    .INPUTS
        Query ID: An identifier for the query​. Once defined this can no longer be changed.
        Parameters: Optional hashtable of parameters used by the query.
    .OUTPUTS
        [Hashtable]
            queryId             string          Identifier of the executed query
            executedQuery       string          Final query executed with the parameters replaced
            rows                integer<int64>  Number of rows returned
            executionDateTime   DateTime        Date and time of the execution
            headers             array[string]   Ordered list with the headers of the returned fields
            data                array[array]    List of row with the data returned by the query execution
                object  . 
    .NOTES
        Times out after 5 seconds.
        
        The Execution DateTime is reformatted from the following fields
            executionDateTime   object          Date and time of the execution
                year            integer<int64>
                month           integer<int64>
                day             integer<int64>
                hour            integer<int64>
                minute          integer<int64>
                second          integer<int64>
    #>
    [CmdletBinding()]
    param(
        [ValidatePattern('^#[A-z_]{2,255}$')]
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$QueryId,
                
        [parameter(Mandatory=$false)]
        [hashtable]$Parameters
    )
    $ApiType = 'NQL'

    $body = @{
        queryId = $QueryId
    }

    # Build Add any optional dynamic parameters for the RA
    if (($null -ne $Parameters) -and ($Parameters.count -ge 1)) {
        $body.Add('parameters', $Parameters)
    }
    $bodyJson = $body | ConvertTo-Json -Depth 4
    
    $r = Invoke-NxtApi -Type $ApiType -Body $bodyJson -ReturnResponse

    # Modify response with proper datetime field for execution
    if ($r.executionDateTime.Year -ge 2023) {
        $tmpDT = [String]::Concat($($r.executionDateTime.year), '-',
                                  $($r.executionDateTime.month), '-',
                                  $($r.executionDateTime.day), ' ',
                                  $($r.executionDateTime.hour), ':',
                                  $($r.executionDateTime.minute), ':',
                                  $($r.executionDateTime.second))
        $r.executionDateTime = [datetime]::ParseExact($tmpDT, "yyyy-M-d H:m:s", $null)
    }
    

    return $r
}