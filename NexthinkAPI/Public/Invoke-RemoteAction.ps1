function Invoke-RemoteAction {
    <#
    .SYNOPSIS
        Triggers RA for devices
    .DESCRIPTION
        Triggers the execution of Remote Actions for 1 or more devivces
    .INPUTS
        remoteActionId - Remote Actions NQL ID
        devices - List (Array) of Device Collector UID values
        parameters - Optional RA Parameters (hashtable)
        expiresInMinutes - The amount of time in minutes before the execution will expire if a targeted device does not come online to process it.
    .OUTPUTS
        Object. 
    .NOTES
        2023.09.27: Updated UID validation

    #>
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('NqlId')]
        # The NQL ID of the Automation workflow.
        [string]$remoteActionId,

        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('DeviceIdList')]
        # An array of device collector UUID values
        [Array]$devices,
        
        [ValidateScript({($_ -ge 60) -and ($_ -le 10080)})]
        [Alias('Expires')]
        # Time to wait for devices execution of RA (60-10080 min)
        [Int]$expiresInMinutes = 60,
                
        # A key value hashtable of parameters for the RA
        [parameter(Mandatory=$false)]
        [hashtable]$Parameters
    )
    $APITYPE = 'RA_Exec'
    
    $body = @{
        remoteActionId = $remoteActionId
        devices = $devices
        expiresInMinutes = $expiresInMinutes
    }

    # Build Add any optional dynamic parameters for the RA
    if (($null -ne $Parameters) -and ($Parameters.count -ge 1)) {
        $body.Add('params', $Parameters)
    }

    $bodyJson = $body | ConvertTo-Json -Depth 4

    Invoke-NxtApi -Type $APITYPE -Body $bodyJson -ReturnResponse
}