function Invoke-ListRemoteActions {
    [OutputType([PSCustomObject])]
    <#
    .SYNOPSIS
        Lists available Remote Actions
    .DESCRIPTION
        Returns an object of RA's enabled for API Consumption
    .INPUTS
        Optional Remote Action ID. This does not accept pipeline input.
    .LINK
        https://github.com/NexthinkGuru/NexthinkAPI/blob/main/README.md#remote-actions
    .LINK
        https://github.com/NexthinkGuru/NexthinkAPI/blob/main/Public/Invoke-ListRemoteActions.ps1
    .OUTPUTS
        Object.
    .NOTES
        ?hasScriptWindows=true&hasScriptMacOs=false
    #>
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$false)]
        [Alias('nqlId')]
        [string]$remoteActionId,

        [ValidateSet("manual", "scheduled", "api", "all")]
        [string]$Targeting = "scheduled"
        
    )
    $APITYPE = 'RA_List'

    $query = $null

    if ($null -ne $remoteActionId -and '' -ne $remoteActionId) {
        $remoteActionIdEncoded = [System.Web.HttpUtility]::UrlEncode($remoteActionId)
        $query = -join ($MAIN.APIs.DETAILS,$remoteActionIdEncoded)
        Write-Verbose "Query: $query"
    }

    $actionList = Invoke-NxtApi -Type $APITYPE -Query $query -ReturnResponse
 
    # Process through the responses, only returning the ones we want.
    if ($null -ne $actionList) {
        foreach ($RA in $actionList) {
            if ($RA.targeting.apiEnabled) { 
                $RA
            }
        } 
    } else {
        $actionList
    }
}