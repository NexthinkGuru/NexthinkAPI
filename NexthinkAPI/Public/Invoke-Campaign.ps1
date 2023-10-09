function Invoke-Campaign {
    <#
    .SYNOPSIS
        Triggers Campaign to Users
    .DESCRIPTION
        Triggers the execution of Remote Actions for 1 or more devivces
    .INPUTS
        CampaignId - Campaign NQL ID
        Users - List (Array) of User SID values
        Parameters - (hashtable) Optional parameter/values
        expiresInMinutes - Campaign expiration in minutes (1-525600) - Defaults to 60m
        This does not accept pipeline input.
    .OUTPUTS
        Object. 
    .NOTES
        2023.09.27: Updated to support Parameters
    #>
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('CampaignNqlId')]
        [string]$CampaignId,

        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('UserIdList')]
        [Array]$Users,

        # A key value hashtable of parameters for the Campaign
        [parameter(Mandatory=$false)]
        [hashtable]$Parameters,
                
        [ValidateScript({($_ -ge 1) -and 
                         ($_ -le 525600)})]
        [Alias('Expires')]
        [Int]$ExpiresInMinutes = 60
    )
    $APITYPE = 'Campaign'

    # Validate the Users containt SID values
    $users | ForEach-Object ({
        if ($_ -notmatch 'S-1-[0-59]-\d{2}-\d{8,10}-\d{8,10}-\d{8,10}-[1-9]\d{3}') {
            $message = "Invalid SID format for one or more users. $_"
            Write-CustomLog -Message $message -Severity "ERROR"
            Throw $($message)
        }
    })

    $body = @{
        campaignNqlId = $CampaignId
        userSid = $users
        expiresInMinutes = $ExpiresInMinutes
    }

    # Build Add any optional dynamic parameters for the RA
    if (($null -ne $Parameters) -and ($Parameters.count -ge 1)) {
        $body.Add('params', $Parameters)
    }
    
    $bodyJson = $body | ConvertTo-Json -Depth 4

    Invoke-NxtApi -Type $APITYPE -Body $bodyJson
}