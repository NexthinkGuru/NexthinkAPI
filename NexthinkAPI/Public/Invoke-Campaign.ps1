function Invoke-Campaign {
    <#
    .SYNOPSIS
        Triggers Campaign to Users
    .DESCRIPTION
        Triggers the execution of Remote Actions for 1 or more devivces
    .INPUTS
        Campaign NQL ID
        List (Array) of User SID values
        Campaign expiration in minutes (1-525600) - Defaults to 60m
        This does not accept pipeline input.
    .OUTPUTS
        Object. 
    .NOTES
    #>
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('campaignNqlId')]
        [string]$CampaignId,

        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('UserIdList')]
        [Array]$Users,
                
        [ValidateScript({($_ -ge 1) -and 
                         ($_ -le 525600)})]
        [Alias('Expires')]
        [Int]$expiresInMinutes = 60
    )
    $ApiType = 'Campaign'

    # Validate the Users containt SID values
    $Users | ForEach-Object ({
        if ($_ -notmatch 'S-1-[0-59]-\d{2}-\d{8,10}-\d{8,10}-\d{8,10}-[1-9]\d{3}') {
            $message = "Invalid SID format for one or more users. $_"
            Write-CustomLog -Message $message -Severity "ERROR"
            Throw $($message)
        }
    })

    $body = @{
        campaignNqlId = $CampaignId
        userSid = $Users
        expiresInMinutes = $expiresInMinutes
    }
    
    $bodyJson = $body | ConvertTo-Json -Depth 4

    Invoke-NxtApi -Type $ApiType -Body $bodyJson
}