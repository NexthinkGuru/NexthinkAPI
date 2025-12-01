function Invoke-Campaign {
    <#
    .SYNOPSIS
        Triggers a Nexthink Campaign for one or more users.
    .DESCRIPTION
        Calls the Nexthink Campaign API to trigger a campaign for the specified user SIDs,
        with optional parameters and an expiration window.
    .INPUTS
        None. This does not accept pipeline input.
    .OUTPUTS
        The response object returned by Invoke-NxtApi.
    .NOTES
        2023.09.27: Updated to support Parameters
        2025.11.xx: Refactored for stricter validation and module-style patterns
    #>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            Position  = 0
        )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if (-not (Test-IsValidNqlId $_)) {
                throw "Invalid NQL Query ID: $_"
            }
            $true
        })]
        [Alias('CampaignNqlId')]
        [string]$CampaignId,

        [Parameter(
            Mandatory = $true,
            Position  = 1
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('UserIdList')]
        [string[]]$Users,

        # A key/value hashtable of parameters for the Campaign
        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters,

        [Parameter(Mandatory = $false)]
        [ValidateScript({
            if ($_ -lt 1 -or $_ -gt 525600) {
                throw "ExpiresInMinutes must be between 1 and 525600 (inclusive)."
            }
            $true
        })]
        [Alias('Expires')]
        [int]$ExpiresInMinutes = 60
    )

    $apiType = 'Campaign'

    # ----------------------------------------------------------------
    # Validate Users array and SID formats
    # ----------------------------------------------------------------
    if (-not $Users -or $Users.Count -eq 0) {
        $message = "Users parameter cannot be empty. At least one user SID is required."
        Write-CustomLog -Message $message -Severity 'ERROR'
        throw $message
    }

    if ($Users.Count -gt 10000) {
        $message = "The Maximum number or users per API call is 10,000. You provided $($Users.Count)."
        Write-CustomLog -Message $message -Severity 'ERROR'
        throw $message
    }

    foreach ($sid in $Users) {
        if (-not (Test-IsValidSID $sid)) {
            $message = "Invalid SID format for user: $sid"
            Write-CustomLog -Message $message -Severity 'ERROR'
            throw $message
        }
    }

    # ----------------------------------------------------------------
    # Build request body
    # ----------------------------------------------------------------
    $body = @{
        campaignNqlId    = $CampaignId
        userSid          = $Users
        expiresInMinutes = $ExpiresInMinutes
    }

    if ($Parameters -and $Parameters.Count -gt 0) {
        $body['params'] = $Parameters
    }

    $bodyJson = $body | ConvertTo-Json -Depth 4

    Write-CustomLog -Message (
        "Invoking Campaign API. CampaignId='{0}', Users={1}, ExpiresInMinutes={2}" -f `
            $CampaignId,
            $Users.Count,
            $ExpiresInMinutes
    ) -Severity 'DEBUG'

    # ----------------------------------------------------------------
    # Call API and return response
    # ----------------------------------------------------------------
    return Invoke-NxtApi -Type $apiType -Body $bodyJson -ReturnResponse
}
