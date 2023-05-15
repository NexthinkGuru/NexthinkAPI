function New-Query {
    <#
    .SYNOPSIS
        Triggers NQL Query creation
    .DESCRIPTION
        Triggers the execution of an NQL query, returning up to 100 results
    .INPUTS
        Query ID: An identifier for the query​. Once defined this can no longer be changed.
        Parameters: Optional hashtable of parameters used by the query.
    .OUTPUTS
        Object. 
    .NOTES
    #>
    [CmdletBinding()]
    param(
        [ValidatePattern('^#[A-z_]*$')]
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Array]$QueryId,
                
        [parameter(Mandatory=$false)]
        [hashtable]$Parameters
    )
    $ApiType = 'NQL'

    $body = @{
        queryId = $QueryId
    }

    # Build Add any optional dynamic parameters for the RA
    if (($null -ne $Parameters) -and ($Parameters.count -ge 1)) {
        $body.Add('params', $Parameters)
    }
    $bodyJson = $body | ConvertTo-Json -Depth 4
    
    Invoke-NxtApi -Type $ApiType -Body $bodyJson
}