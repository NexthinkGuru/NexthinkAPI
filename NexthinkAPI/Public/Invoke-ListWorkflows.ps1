function Invoke-ListWorkflows {
    [OutputType([PSCustomObject])]
    <#
    .SYNOPSIS
        Lists available Workflows
    .DESCRIPTION
        Returns an object of Workflows's enabled for API Consumption
    .INPUTS
        Optional Workflows ID. This does not accept pipeline input.
    .OUTPUTS
        Object.
    .NOTES
        ?hasScriptWindows=true&hasScriptMacOs=false
    #>
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$false)]
        [Alias('nqlId')]
        [string]$workflowId
    )
    $ApiType = 'WF_List'

    $query = $null

    if ($null -ne $workflowId -and '' -ne $workflowId) {
        $workflowIdEncoded = [System.Web.HttpUtility]::UrlEncode($workflowId)
        $query = -join ($MAIN.APIs.DETAILS.uri,$workflowIdEncoded)
        Write-Verbose "Query: $query"
    }

    $workflowList = Invoke-NxtApi -Type $ApiType -Query $query -ReturnResponse
 
    # Process through the responses, only returning the ones we want.
    if ($null -ne $workflowList) {
        foreach ($WF in $workflowList) {
            if ($WF.triggerMethods.apiEnabled) { 
                $WF
            }
        } 
    } else {
        $workflowList
    }
}