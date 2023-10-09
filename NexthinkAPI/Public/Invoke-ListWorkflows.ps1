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
        [string]$WorkflowId
    )
    $APITYPE = 'WF_List'

    $query = $null

    if ($null -ne $WorkflowId -and '' -ne $WorkflowId) {
        $workflowIdEncoded = [System.Web.HttpUtility]::UrlEncode($WorkflowId)
        $query = -join ($MAIN.APIs.DETAILS,$workflowIdEncoded)
        Write-Verbose "Query: $query"
    } else {  # Added to address Pre-release version of Workflow API's
        $query = "/workflows"
    }

    $workflowList = Invoke-NxtApi -Type $APITYPE -Query $query -ReturnResponse
 
    # Process through the responses, only returning the ones we want.
    if ($null -ne $workflowList) {
        foreach ($workflow in $workflowList) {
            if ($workflow.triggerMethods.apiEnabled) { 
                $workflow
            }
        } 
    } else {
        $workflowList
    }
}