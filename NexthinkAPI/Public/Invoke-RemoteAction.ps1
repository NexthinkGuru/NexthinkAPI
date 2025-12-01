function Invoke-RemoteAction {
    <#
    .SYNOPSIS
        Triggers a Nexthink Remote Action for one or more devices.
    .DESCRIPTION
        Triggers the execution of a Remote Action for one or more devices, with optional
        parameters and an expiration window for when offline devices can still run it.
    .INPUTS
        None. This does not accept pipeline input.
    .OUTPUTS
        The response object returned by Invoke-NxtApi.
    .NOTES
        2023-09-27: Updated UID validation
        2025-11-30: Refactored for stricter validation and module-style patterns
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
        [Alias('NqlId')]
        # The NQL ID of the Remote Action.
        [string]$RemoteActionId,

        [Parameter(
            Mandatory = $true,
            Position  = 1
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('DeviceIdList')]
        [ValidateScript({
            if (-not $_ -or $_.Count -eq 0) {
                throw "Devices parameter cannot be empty. At least one device UID is required."
            }
            if ($_.Count -gt 10000) {
                throw "Only 10,000 devices can be targeted in a single RA invocation. You provided $($_.Count)."
            }

            foreach ($d in $_) {
                if (-not ($d -is [string])) {
                    throw "Each device ID must be a string. Got: [$($d.GetType().FullName)]."
                }

                # Validate UUID format (Collector UID must be a real UUID)
                $out = [Guid]::Empty
                if (-not [Guid]::TryParse($d, [ref]$out)) {
                    throw "Device UID '$d' is not a valid UUID."
                }
            }
            $true
        })]
        # An array of device collector UID values
        [string[]]$Devices,

        [Parameter(Mandatory = $false)]
        [ValidateScript({
            if ($_ -lt 60 -or $_ -gt 10080) {
                throw "ExpiresInMinutes must be between 60 and 10080 (inclusive)."
            }
            $true
        })]
        [Alias('Expires')]
        # Time to wait for devices to execute the RA (60–10080 minutes)
        [int]$ExpiresInMinutes = 60,

        # A key/value hashtable of parameters for the RA
        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters
    )

    $apiType = 'RA_Exec'

    # ----------------------------------------------------------------
    # Build request body
    # ----------------------------------------------------------------
    $body = @{
        remoteActionId    = $RemoteActionId
        devices           = $Devices
        expiresInMinutes  = $ExpiresInMinutes
    }

    if ($Parameters -and $Parameters.Count -gt 0) {
        $body['params'] = $Parameters
    }

    $bodyJson = $body | ConvertTo-Json -Depth 4

    Write-CustomLog -Message (
        "Invoking Remote Action. RemoteActionId='{0}', Devices={1}, ExpiresInMinutes={2}" -f `
            $RemoteActionId,
            ($Devices -join ','),
            $ExpiresInMinutes
    ) -Severity 'DEBUG'

    # ----------------------------------------------------------------
    # Call API and return response
    # ----------------------------------------------------------------
    return Invoke-NxtApi -Type $apiType -Body $bodyJson -ReturnResponse
}
