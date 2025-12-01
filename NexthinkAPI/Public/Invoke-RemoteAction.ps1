function Invoke-RemoteAction {
    <#
    .SYNOPSIS
        Triggers a Nexthink Remote Action for one or more devices.

    .DESCRIPTION
        Triggers the execution of a Nexthink Remote Action for a set of target
        devices, with an optional expiration window and optional parameter set.

        This function:
          - Validates the Remote Action NQL ID using Test-IsValidNqlId.
          - Ensures the Devices list contains between 1 and 10,000 entries.
          - Validates each device entry as a proper UUID (Collector UID).
          - Enforces an execution window of 60–10080 minutes.
          - Passes an optional parameter hashtable through to the RA.
          - Calls the internal Invoke-NxtApi helper and returns its response.

    .PARAMETER RemoteActionId
        The NQL ID of the Remote Action to execute.

        This must be a valid NQL identifier (for example: "#remote_action_id")
        and is validated using Test-IsValidNqlId.

        Alias:
            NqlId

    .PARAMETER Devices
        The list of devices (Collector UIDs) that should execute the Remote Action.

        Requirements:
          - At least 1 device must be provided.
          - A maximum of 10,000 device IDs is allowed.
          - Each entry must be a string.
          - Each entry must be a valid UUID (Collector UID).

        Alias:
            DeviceIdList

        Examples:
            '3fa85f64-5717-4562-b3fc-2c963f66afa6'
            '0e8a9a54-9fd8-4e9a-83f4-4d611f9d1234'

    .PARAMETER ExpiresInMinutes
        The time window, in minutes, during which targeted devices may execute
        the Remote Action.

        This controls how long offline devices are allowed to come online and
        still process the queued RA execution.

        Constraints:
          - Minimum: 60 minutes
          - Maximum: 10080 minutes (7 days)

        Default:
          60

        Alias:
            Expires

    .PARAMETER Parameters
        Optional key/value hashtable of parameters to pass to the Remote Action.

        Keys:
          - Must be valid parameter names as defined in the RA.

        Values:
          - Should be types that serialize cleanly to JSON (string, int, bool,
            or arrays of these), depending on how the RA expects them.

        Example:
            @{
                "reason"   = "Health check"
                "priority" = 1
            }

    .INPUTS
        None. This function does not accept pipeline input.

    .OUTPUTS
        [object]

        Returns the response object produced by Invoke-NxtApi, which typically
        contains the RA execution request metadata and status from the Nexthink
        API.

    .EXAMPLE
        Invoke-RemoteAction `
            -RemoteActionId '#reboot_devices' `
            -Devices @(
                '3fa85f64-5717-4562-b3fc-2c963f66afa6',
                '0e8a9a54-9fd8-4e9a-83f4-4d611f9d1234'
            )

        Triggers the '#reboot_devices' Remote Action on the specified devices
        with the default 60-minute execution window and no additional parameters.

    .EXAMPLE
        $params = @{
            "reason"      = "Patch Tuesday"
            "forceReboot" = $true
        }

        Invoke-RemoteAction `
            -RemoteActionId '#maintenance_ra' `
            -Devices @('3fa85f64-5717-4562-b3fc-2c963f66afa6') `
            -ExpiresInMinutes 240 `
            -Parameters $params

        Triggers the '#maintenance_ra' Remote Action on one device, allowing up
        to 4 hours for execution and passing additional context parameters.

    .NOTES
        2023-09-27: Initial UID validation added.
        2025-11-30: Refactored for stricter validation and module-style patterns.
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
        [Alias('NqlId')]
        # The NQL ID of the Remote Action.
        [string]$RemoteActionId,

        [Parameter(
            Mandatory = $true,
            Position = 1
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
        remoteActionId   = $RemoteActionId
        devices          = $Devices
        expiresInMinutes = $ExpiresInMinutes
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
