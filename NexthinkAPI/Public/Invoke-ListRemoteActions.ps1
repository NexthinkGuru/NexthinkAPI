function Invoke-ListRemoteActions {
    <#
.SYNOPSIS
    Lists Nexthink Remote Actions, optionally filtered by NQL ID and targeting mode.

.DESCRIPTION
    Retrieves Remote Actions from Nexthink via the RA_List API and returns them
    as PSCustomObject instances.

    Behavior:
      - If -RemoteActionId is specified:
          • Calls the Remote Action details endpoint for that specific NQL ID.
          • Returns the single RA object (subject to targeting filter if 'all'
            is not used and the object has targeting flags).
      - If -RemoteActionId is not specified:
          • Calls the list endpoint and returns all Remote Actions, filtered
            according to -Targeting.

    The Targeting parameter controls client-side filtering based on the RA’s
    targeting flags:

      - manual    → targeting.manualEnabled    -eq $true
      - scheduled → targeting.scheduledEnabled -eq $true
      - api       → targeting.apiEnabled       -eq $true
      - all       → no targeting filter applied

.PARAMETER RemoteActionId
    Optional NQL ID of a specific Remote Action to retrieve.

    When provided, a details endpoint is called for this NQL ID. The value is
    validated using Test-IsValidNqlId.

    Alias:
        NqlId

    Example:
        "#remote_action_reboot"

.PARAMETER Targeting
    Specifies which targeting mode to filter Remote Actions on.

    Valid values:
        manual     - Only RAs with targeting.manualEnabled    = $true
        scheduled  - Only RAs with targeting.scheduledEnabled = $true
        api        - Only RAs with targeting.apiEnabled       = $true
        all        - No targeting filter; return all RAs

    Default:
        api

.INPUTS
    None. This function does not accept pipeline input.

.OUTPUTS
    [PSCustomObject[]]

    Returns one or more PSCustomObject instances representing Remote Actions
    returned by the Nexthink API. If no Remote Actions are returned, an empty
    array (@()) is returned.

.EXAMPLE
    Invoke-ListRemoteActions

    Lists all Remote Actions that are enabled for API targeting.

.EXAMPLE
    Invoke-ListRemoteActions -Targeting manual

    Lists all Remote Actions that are enabled for manual targeting.

.EXAMPLE
    Invoke-ListRemoteActions -Targeting all

    Lists all Remote Actions without applying any targeting filter.

.EXAMPLE
    Invoke-ListRemoteActions -RemoteActionId "#remote_action_reboot"

    Retrieves details for the specified Remote Action NQL ID.

.NOTES
    - Normalizes the API response to an array even when a single object
      is returned.
    - 2025-11-30: Refactored for stricter validation and module-style patterns.
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [Alias('NqlId')]
        [ValidateScript({
                if ([string]::IsNullOrWhiteSpace($_)) {
                    return $true
                }
                if (-not (Test-IsValidNqlId $_)) {
                    throw "Invalid NQL Query ID: $_"
                }
                $true
            })]
        [string]$RemoteActionId,

        [Parameter(Mandatory = $false)]
        [ValidateSet('manual', 'scheduled', 'api', 'all')]
        [string]$Targeting = 'api'
    )

    $apiType = 'RA_List'
    $query = $null

    # If a specific RA is requested, build the details URL
    if (-not [string]::IsNullOrWhiteSpace($RemoteActionId)) {
        $remoteActionIdEncoded = [System.Web.HttpUtility]::UrlEncode($RemoteActionId)
        $query = -join ($MAIN.APIs.$apiType.Details, $remoteActionIdEncoded)

        Write-CustomLog -Message ("Invoke-ListRemoteActions: Query (details) = {0}" -f $query) -Severity 'DEBUG'
    }
    else {
        Write-CustomLog -Message "Invoke-ListRemoteActions: Listing all Remote Actions" -Severity 'DEBUG'
    }

    # Call API
    $actionList = Invoke-NxtApi -Type $apiType -Query $query -ReturnResponse

    if (-not $actionList) {
        Write-CustomLog -Message "Invoke-ListRemoteActions: No Remote Actions returned from API." -Severity 'DEBUG'
        return @()
    }

    # Normalize to array in case a single object is returned
    if ($actionList -isnot [System.Collections.IEnumerable] -or $actionList -is [string]) {
        $actionList = @($actionList)
    }

    # Apply targeting filter
    $filtered = switch ($Targeting) {

        'api' { $actionList | Where-Object { $_.targeting.apiEnabled } }
        'manual' { $actionList | Where-Object { $_.targeting.manualEnabled } }
        'scheduled' { $actionList | Where-Object { $_.targeting.scheduledEnabled } }
        'all' { $actionList }
    }

    Write-CustomLog -Message (
        "Invoke-ListRemoteActions: Returning {0} Remote Action(s) for targeting='{1}'." -f `
        (@($filtered).Count), $Targeting
    ) -Severity 'DEBUG'

    return $filtered
}
