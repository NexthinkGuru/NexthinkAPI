function Invoke-ListRemoteActions {
    <#
    .SYNOPSIS
        Lists available Remote Actions.
    .DESCRIPTION
        Returns Remote Actions enabled for a given targeting mode (manual, scheduled, api, or all).
        Optionally filters by a specific Remote Action NQL ID.
    .INPUTS
        None. This does not accept pipeline input.
    .OUTPUTS
        [PSCustomObject] (one per Remote Action).
    .NOTES
        Targeting:
          - manual   -> targeting.manualEnabled -eq $true
          - scheduled-> targeting.scheduledEnabled -eq $true
          - api      -> targeting.apiEnabled -eq $true
          - all      -> no targeting filter

        2025-11-30: Refactored for stricter validation and module-style patterns
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
        [ValidateSet('manual','scheduled','api','all')]
        [string]$Targeting = 'api'
    )

    $apiType = 'RA_List'
    $query   = $null

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

        'api'       { $actionList | Where-Object { $_.targeting.apiEnabled } }
        'manual'    { $actionList | Where-Object { $_.targeting.manualEnabled } }
        'scheduled' { $actionList | Where-Object { $_.targeting.scheduledEnabled } }
        'all'       { $actionList }
    }

    Write-CustomLog -Message (
        "Invoke-ListRemoteActions: Returning {0} Remote Action(s) for targeting='{1}'." -f `
            (@($filtered).Count), $Targeting
    ) -Severity 'DEBUG'

    return $filtered
}
