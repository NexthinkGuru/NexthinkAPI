function New-Query {
    <#
    .SYNOPSIS
        Triggers NQL Query creation
    .DESCRIPTION
        Triggers the execution of an NQL query, returning up to 100 results
    .INPUTS
        Name: The name as you would like it to appear on the list of queries.
        Query ID: An identifier for the query​. Once defined this can no longer be changed.
        Description: A description to help other users understand the meaning and purpose of the query.
    .OUTPUTS
        Object. 
    .NOTES
    #>
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Array]$QueryId,
                
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Array]$Description
    )
    $ApiType = 'NewNqlQuery'

    $body = @{
        campaignNqlId = $CampaignId
        userSid = $Users
        expiresInMinutes = $Expires
    }
    
    $bodyJson = $body | ConvertTo-Json -Depth 4

    Invoke-NxtApi -Type $ApiType -Body $bodyJson
}