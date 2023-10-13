function Invoke-EnrichmentRequest {
    <#
    .SYNOPSIS
        Enriches Nexthink Objects
    .DESCRIPTION
        PUTs data to the Nexthink Enrichment API endpoint for updating.
    .INPUTS
        None. This does not accept pipeline input.
    .OUTPUTS
        Object. 
    .NOTES
    #>
    [CmdletBinding()]
    param(
        # the body of the request. Object
        [parameter(Mandatory=$true)]
        [Alias('Body')]
        [PSCustomObject]$Enrichment
    )
    $APITYPE = 'Enrich'

    $bodyJson = $Enrichment | ConvertTo-Json -Depth 8 -Compress

    Invoke-NxtApi -Type $APITYPE -Body $bodyJson

}