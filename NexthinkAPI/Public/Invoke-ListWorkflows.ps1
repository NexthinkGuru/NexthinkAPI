function Invoke-ListWorkflows {
    <#
    .SYNOPSIS
        Lists Nexthink Automation Workflows, optionally filtered by targeting and trigger method.

    .DESCRIPTION
        Retrieves Nexthink Automation Workflows either:

          - As a single workflow (when WorkflowId is provided), or
          - As a filtered list using the group query parameters:

                dependency              : USER, DEVICE, USER_AND_DEVICE, NONE
                triggerMethod           : API, MANUAL, MANUAL_MULTIPLE, SCHEDULER
                fetchOnlyActiveWorkflows: $true / $false

        When no WorkflowId is specified, this function builds a query against the
        workflows list endpoint, applying the requested filters.

        By default, it returns only **active** workflows that are triggered via **API**
        (to match the previous behavior of filtering on triggerMethods.apiEnabled).

    .PARAMETER WorkflowId
        Optional NQL ID of a specific Workflow.

        When provided:
          - The function calls the workflow details endpoint (similar to Remote Actions).
          - Group query filters (Dependency, TriggerMethod, FetchOnlyActiveWorkflows)
            are ignored.

        Alias:
            nqlId

    .PARAMETER Dependency
        Required dependency type for filtering workflows by their targeting model.

        Valid values:
            USER
            DEVICE
            USER_AND_DEVICE
            NONE

        Default:
            DEVICE

        Examples:
            -Dependency USER
            -Dependency DEVICE

    .PARAMETER TriggerMethod
        Required trigger method filter.

        Valid values:
            API
            MANUAL
            MANUAL_MULTIPLE
            SCHEDULER

        Default:
            API

        This preserves the historical behavior of “workflows enabled for API consumption”.

    .PARAMETER FetchOnlyActiveWorkflows
        Specifies whether to fetch only active workflows.

        Default:
            $true

        Set to $false to include inactive workflows in the results.

    .INPUTS
        None. This function does not accept pipeline input.

    .OUTPUTS
        [PSCustomObject[]]

        - When WorkflowId is provided: a single workflow object (or whatever
          the API returns for the details endpoint).
        - When WorkflowId is not provided: an array of workflow objects
          matching the provided filters (or an empty array if none).

    .EXAMPLE
        # List all active workflows that can be triggered via API
        Invoke-ListWorkflows

    .EXAMPLE
        # List active workflows that depend on both user and device context
        Invoke-ListWorkflows -Dependency USER_AND_DEVICE

    .EXAMPLE
        # List all scheduled workflows (active only)
        Invoke-ListWorkflows -TriggerMethod SCHEDULER

    .EXAMPLE
        # Include all workflows as well
        Invoke-ListWorkflows -FetchOnlyActiveWorkflows:$true

    .EXAMPLE
        # Get a specific workflow by NQL ID
        Invoke-ListWorkflows -WorkflowId '#workflow_example'

    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [Alias('nqlId')]
        [ValidateScript({
                if ([string]::IsNullOrWhiteSpace($_)) { return $true }
                if (-not (Test-IsValidNqlId $_)) {
                    throw "Invalid NQL Query ID: $_"
                }
                $true
            })]
        [string]$WorkflowId,

        [Parameter(Mandatory = $false)]
        [ValidateSet('USER', 'DEVICE', 'USER_AND_DEVICE', 'NONE')]
        [string]$Dependency = 'DEVICE',

        [Parameter(Mandatory = $false)]
        [ValidateSet('API', 'MANUAL', 'MANUAL_MULTIPLE', 'SCHEDULER')]
        [string]$TriggerMethod = 'API',

        [Parameter(Mandatory = $false)]
        [bool]$FetchOnlyActiveWorkflows = $false
    )

    $apiType = 'WF_List'
    $query = $null

    if (-not [string]::IsNullOrWhiteSpace($WorkflowId)) {
        # Details endpoint for a single workflow
        $workflowIdEncoded = [System.Web.HttpUtility]::UrlEncode($WorkflowId)
        $query = -join ($MAIN.APIs.$apiType.Details, $workflowIdEncoded)

        Write-CustomLog -Message ("Invoke-ListWorkflows: Details query = {0}" -f $query) -Severity 'DEBUG'
    }
    else {
        # Group/list endpoint with optional filters
        $queryParams = New-Object 'System.Collections.Generic.List[string]'
        $queryParams.Add('dependency={0}'               -f [System.Web.HttpUtility]::UrlEncode($Dependency))
        $queryParams.Add('triggerMethod={0}'            -f [System.Web.HttpUtility]::UrlEncode($TriggerMethod))
        $queryParams.Add('fetchOnlyActiveWorkflows={0}' -f ($FetchOnlyActiveWorkflows.ToString().ToLowerInvariant()))

        $query = '?{0}' -f ($queryParams -join '&')

        Write-CustomLog -Message ("Invoke-ListWorkflows: List query = {0}" -f $query) -Severity 'DEBUG'
    }

    $workflowList = Invoke-NxtApi -Type $apiType -Query $query -ReturnResponse

    if (-not $workflowList) {
        Write-CustomLog -Message "Invoke-ListWorkflows: No workflows returned from API." -Severity 'DEBUG'
        return @()
    }

    # Normalize to array if API returns a single object
    if ($workflowList -isnot [System.Collections.IEnumerable] -or
        $workflowList -is [string]) {

        $workflowList = @($workflowList)
    }

    # # Fallback safety filter: if we're listing (no specific WorkflowId)
    # # and triggerMethod is API, some older backends might ignore the
    # # query parameter — so we also filter client-side when applicable.
    # if (-not $WorkflowId -and $TriggerMethod -eq 'API') {
    #     $workflowList = $workflowList | Where-Object {
    #         $_.triggerMethods -and $_.triggerMethods.apiEnabled
    #     }
    # }

    Write-CustomLog -Message (
        "Invoke-ListWorkflows: Returning {0} workflow(s) [WorkflowId={1}, Dependency={2}, TriggerMethod={3}, ActiveOnly={4}]" -f `
                     @($workflowList).Count, $WorkflowId, $Dependency, $TriggerMethod, $FetchOnlyActiveWorkflows
        ) -Severity 'DEBUG'

    return $workflowList
}
