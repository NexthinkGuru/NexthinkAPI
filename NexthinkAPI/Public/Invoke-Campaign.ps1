function Invoke-Campaign {
    <#
.SYNOPSIS
    Triggers a Nexthink Campaign for one or more users.

.DESCRIPTION
    Executes a Nexthink Campaign by sending one or more user SIDs to the
    Campaign API endpoint. Optional campaign parameters can be supplied, along
    with an expiration window that determines how long offline users may take
    to receive and process the campaign.

    CampaignId must be a valid NQL ID (validated via Test-IsValidNqlId).
    User identifiers must be valid Windows SIDs (validated via Test-IsValidSID).

.PARAMETER CampaignId
    The NQL ID of the Campaign to trigger.
    Must be a valid NQL identifier (e.g., '#my_campaign').

.PARAMETER Users
    An array of user SIDs to target.
    Requirements:
        • Must contain between 1 and 10,000 entries.
        • Each entry must be a syntactically valid SID.
    Example SID: S-1-5-21-1234567890-123456789-1234567890-1001

.PARAMETER Parameters
    Optional hashtable of key/value pairs passed to the Campaign during execution.
    If omitted, no additional parameters are sent.

.PARAMETER ExpiresInMinutes
    The maximum time in minutes that the platform will wait for targeted users
    to be online and eligible to receive the Campaign.
    Must be between 1 and 525,600 minutes.
    Defaults to 60.

.INPUTS
    None. This function does not accept pipeline input.

.OUTPUTS
    [object]
        Returns the response object produced by Invoke-NxtApi for the Campaign request.

.EXAMPLE
    Invoke-Campaign -CampaignId "#campaign_onboarding" `
                    -Users @("S-1-5-21-12345-67890-11111-2222")

    Triggers the onboarding Campaign for the specified user SID.

.EXAMPLE
    Invoke-Campaign -CampaignId "#survey_campaign" `
                    -Users $UserSidList `
                    -Parameters @{ questionSet = "Q1" } `
                    -ExpiresInMinutes 120

    Fires the Campaign with custom parameters, allowing 2 hours for execution.

.NOTES
    2023-09-27: Added support for campaign parameters.
    2025-11-30: Rewritten with strict validation, module-consistent patterns,
                and full SID validation.
#>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            Position = 0
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
            Position = 1
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
