function Invoke-ListRemoteActions {
    [OutputType([PSCustomObject])]
    <#
    .SYNOPSIS
        Lists available Remote Actions
    .DESCRIPTION
        Returns an object of RA's enabled for API Consumption
    .INPUTS
        Optional Remote Action ID. This does not accept pipeline input.
    .OUTPUTS
        Object.
    .NOTES
        ?hasScriptWindows=true&hasScriptMacOs=false
    #>
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$false)]
        [Alias('nqlId')]
        [string]$remoteActionId
    )
    $ApiType = 'RA_List'

    $query = $null

    if ($null -ne $remoteActionId -and '' -ne $remoteActionId) {
        $remoteActionIdEncoded = [System.Web.HttpUtility]::UrlEncode($remoteActionId)
        $query = -join ($MAIN.APIs.DETAILS,$remoteActionIdEncoded)
        Write-Verbose "Query: $query"
    }

    $actionList = Invoke-NxtApi -Type $ApiType -Query $query -ReturnResponse
 
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