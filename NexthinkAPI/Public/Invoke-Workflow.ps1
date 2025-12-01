function Invoke-Workflow {
    <#
    .SYNOPSIS
        Triggers a Nexthink Automation Workflow for devices and/or users.

    .DESCRIPTION
        Triggers the execution of a Workflow using external identifiers for
        devices and/or users.

        For users, each entry can specify one or more of:
          - sid : Security Identifier (SID)
          - upn : User Principal Name (email format)
          - uid : Globally unique user identifier

        For devices, each entry can specify one or more of:
          - collectorUid : Nexthink Collector UUID
          - name        : Device name
          - uid         : Globally unique device identifier

        This function accepts:
          - Simple strings (for common cases)
          - Rich objects/hashtables with explicit identifier properties

        Rules:
          - Up to 10,000 device entries
          - Up to 10,000 user entries
          - At least one of Devices or Users must be provided

        Examples:
          - Devices as plain collector UUIDs (string[])
          - Users as plain SIDs (string[])
          - Mixed/explicit identifiers using hashtables/PSCustomObjects

    .PARAMETER WorkflowId
        The NQL ID of the Automation Workflow to trigger.

        Must be a valid NQL identifier (e.g. "#workflow_example"), validated
        using Test-IsValidNqlId.

        Alias:
            NqlID

    .PARAMETER Devices
        Optional list of devices to target.

        Each entry MAY be:
          - A string:
              Treated as collectorUid (validated as a UUID)
          - A hashtable / PSCustomObject with any of:
              collectorUid : string, validated as UUID if present
              name         : non-empty string
              uid          : non-empty string (globally unique device ID)

        Constraints:
          - Up to 10,000 entries
          - At least one of collectorUid, name, uid must be present per entry

        Alias:
            DeviceIdList

        Examples:
            # Simple collector UIDs
            -Devices @(
                '3fa85f64-5717-4562-b3fc-2c963f66afa6',
                '0e8a9a54-9fd8-4e9a-83f4-4d611f9d1234'
            )

            # Explicit identifiers
            -Devices @(
                @{ collectorUid = '3fa85f64-5717-4562-b3fc-2c963f66afa6' },
                @{ name        = 'LAPTOP-1234'; uid = 'dev-000123' }
            )

    .PARAMETER Users
        Optional list of users to target.

        Each entry MAY be:
          - A string:
              Treated as SID (validated with Test-IsValidSID)
          - A hashtable / PSCustomObject with any of:
              sid : string, validated as SID if present
              upn : string, validated as basic email-like UPN if present
              uid : non-empty string (globally unique user ID)

        Constraints:
          - Up to 10,000 entries
          - At least one of sid, upn, uid must be present per entry

        Alias:
            UserIdList

        Examples:
            # Simple SIDs
            -Users @(
                'S-1-5-21-1234567890-1234567890-1234567890-1001',
                'S-1-5-21-1234567890-1234567890-1234567890-1002'
            )

            # Explicit identifiers
            -Users @(
                @{ sid = 'S-1-5-21-1234-5678-9012-1001' },
                @{ upn = 'user1@contoso.com' },
                @{ uid = 'user-global-id-001'; upn = 'user2@contoso.com' }
            )

    .PARAMETER Parameters
        Optional key/value hashtable of workflow parameters.

        Keys:
          - Must be non-empty strings.

        Values:
          - string, int, bool
          - or arrays of string/int/bool

    .INPUTS
        None. This function does not accept pipeline input.

    .OUTPUTS
        [object]

        Returns the response object from Invoke-NxtApi, which typically includes
        a requestUuid representing the workflow execution request.

    .EXAMPLE
        Invoke-Workflow `
            -WorkflowId '#workflow_example' `
            -Devices @('3fa85f64-5717-4562-b3fc-2c963f66afa6')

    .EXAMPLE
        Invoke-Workflow `
            -WorkflowId '#workflow_example' `
            -Users @(
                'S-1-5-21-1234567890-1234567890-1234567890-1001',
                @{ upn = 'user1@contoso.com' }
            )

    .EXAMPLE
        $devices = @(
            @{ collectorUid = '3fa85f64-5717-4562-b3fc-2c963f66afa6' }
            @{ name        = 'LAPTOP-1234' }
        )

        $users = @(
            @{ sid = 'S-1-5-21-1234567890-1234567890-1234567890-1001' }
            @{ upn = 'user1@contoso.com'; uid = 'user-global-001' }
        )

        $params = @{
            reason   = 'Standard workflow run'
            priority = 1
        }

        Invoke-Workflow `
            -WorkflowId '#complex_workflow' `
            -Devices $devices `
            -Users   $users `
            -Parameters $params

    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(
            Mandatory = $true,
            Position  = 0
        )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if (-not (Test-IsValidNqlId $_)) { throw "Invalid NQL Query ID: $_" }
            $true
        })]
        [Alias('NqlID')]
        [string]$WorkflowId,

        [Parameter(
            Mandatory = $false,
            Position  = 1
        )]
        [Alias('DeviceIdList')]
        [ValidateScript({
            if ($null -eq $_) { return $true }

            if ($_.Count -gt 10000) { throw "Devices cannot contain more than 10,000 entries." }

            foreach ($entry in $_) {
                # Simple string -> collectorUid
                if ($entry -is [string]) {
                    $guid = [Guid]::Empty
                    if (-not [Guid]::TryParse($entry, [ref]$guid)) {
                        throw "Device value '$entry' is a string and is treated as collectorUid, but it is not a valid UUID."
                    }
                    continue
                }

                if (-not ($entry -is [hashtable] -or $entry -is [psobject])) {
                    throw "Each device entry must be a string, hashtable, or PSCustomObject. Got: [$($entry.GetType().FullName)]."
                }

                $collectorUid = $null
                $name         = $null
                $uid          = $null

                if ($entry.PSObject.Properties['collectorUid']) {
                    $collectorUid = [string]$entry.collectorUid
                }
                if ($entry.PSObject.Properties['name']) {
                    $name = [string]$entry.name
                }
                if ($entry.PSObject.Properties['uid']) {
                    $uid = [string]$entry.uid
                }

                if (-not $collectorUid -and -not $name -and -not $uid) {
                    throw "Each device entry must specify at least one of: collectorUid, name, uid."
                }

                if ($collectorUid) {
                    $guid = [Guid]::Empty
                    if (-not [Guid]::TryParse($collectorUid, [ref]$guid)) {
                        throw "collectorUid '$collectorUid' is not a valid UUID."
                    }
                }

                if ($name -and [string]::IsNullOrWhiteSpace($name)) {
                    throw "Device name cannot be empty or whitespace."
                }

                if ($uid -and [string]::IsNullOrWhiteSpace($uid)) {
                    throw "Device uid cannot be empty or whitespace."
                }
            }

            $true
        })]
        [object[]]$Devices,

        [Parameter(
            Mandatory = $false,
            Position  = 2
        )]
        [Alias('UserIdList')]
        [ValidateScript({
            if ($null -eq $_) { return $true }
            if ($_.Count -gt 10000) { throw "Users cannot contain more than 10,000 entries." }

            foreach ($entry in $_) {
                # Simple string -> SID
                if ($entry -is [string]) {
                    if (-not (Test-IsValidSID $entry)) {
                        throw "User value '$entry' is a string and is treated as SID, but it is not a valid security identifier."
                    }
                    continue
                }

                if (-not ($entry -is [hashtable] -or $entry -is [psobject])) {
                    throw "Each user entry must be a string, hashtable, or PSCustomObject. Got: [$($entry.GetType().FullName)]."
                }

                $sid = $null
                $upn = $null
                $uid = $null

                if ($entry.PSObject.Properties['sid']) { $sid = [string]$entry.sid }
                if ($entry.PSObject.Properties['upn']) { $upn = [string]$entry.upn }
                if ($entry.PSObject.Properties['uid']) { $uid = [string]$entry.uid }

                if (-not $sid -and -not $upn -and -not $uid) { throw "Each user entry must specify at least one of: sid, upn, uid." }
                if ($sid -and -not (Test-IsValidSID $sid)) { throw "sid '$sid' is not a valid security identifier." }
                if ($upn -and $upn -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') { throw "upn '$upn' does not appear to be a valid UPN/email format." }
                if ($uid -and [string]::IsNullOrWhiteSpace($uid)) { throw "User uid cannot be empty or whitespace." }
            }

            $true
        })]
        [object[]]$Users,

        [Parameter(Mandatory = $false)]
        [ValidateScript({
            if ($null -eq $_ -or $_.Count -eq 0) { return $true }

            foreach ($key in $_.Keys) {
                if (-not ($key -is [string]) -or [string]::IsNullOrWhiteSpace($key)) {
                    throw "All workflow parameter names must be non-empty strings. Invalid key: '$key'"
                }
            }

            foreach ($value in $_.Values) {
                if ($null -eq $value) { continue }

                if ($value -is [array]) {
                    foreach ($item in $value) {
                        if ($null -eq $item) { continue }
                        if (-not ($item -is [string] -or $item -is [int] -or $item -is [bool])) {
                            throw "Workflow parameter array values must be string, int, or bool. Got: [$($item.GetType().FullName)]."
                        }
                    }
                }
                elseif (-not ($value -is [string] -or $value -is [int] -or $value -is [bool])) {
                    throw "Workflow parameter values must be string, int, or bool (or arrays of these). Got: [$($value.GetType().FullName)]."
                }
            }

            $true
        })]
        [hashtable]$Parameters
    )

    $apiType = 'WF_Exec'

    # Ensure at least one target collection is provided
    if ((-not $Devices -or $Devices.Count -eq 0) -and
        (-not $Users   -or $Users.Count   -eq 0)) {

        $message = "You must specify at least one device or one user. Both parameters cannot be empty."
        Write-CustomLog -Message $message -Severity 'ERROR'
        throw $message
    }

    # ----------------------------------------------------------------
    # Build request body for new external-identifier model
    # ----------------------------------------------------------------
    $body = @{
        workflowId = $WorkflowId
    }

    if ($Devices -and $Devices.Count -gt 0) {
        $body.devices = foreach ($entry in $Devices) {
            if ($entry -is [string]) {
                # String → collectorUid
                [PSCustomObject]@{ collectorUid = $entry }
            }
            else {
                $deviceObj = [ordered]@{}
                if ($entry.PSObject.Properties['collectorUid'] -and $entry.collectorUid) {
                    $deviceObj.collectorUid = [string]$entry.collectorUid
                }
                if ($entry.PSObject.Properties['name'] -and $entry.name) {
                    $deviceObj.name = [string]$entry.name
                }
                if ($entry.PSObject.Properties['uid'] -and $entry.uid) {
                    $deviceObj.uid = [string]$entry.uid
                }
                [PSCustomObject]$deviceObj
            }
        }
    }

    if ($Users -and $Users.Count -gt 0) {
        $body.users = foreach ($entry in $Users) {
            if ($entry -is [string]) {
                # String → SID
                [PSCustomObject]@{ sid = $entry }
            }
            else {
                $userObj = [ordered]@{}
                if ($entry.PSObject.Properties['sid'] -and $entry.sid) {
                    $userObj.sid = [string]$entry.sid
                }
                if ($entry.PSObject.Properties['upn'] -and $entry.upn) {
                    $userObj.upn = [string]$entry.upn
                }
                if ($entry.PSObject.Properties['uid'] -and $entry.uid) {
                    $userObj.uid = [string]$entry.uid
                }
                [PSCustomObject]$userObj
            }
        }
    }

    if ($Parameters -and $Parameters.Count -gt 0) {
        $body.params = $Parameters
    }

    $bodyJson = $body | ConvertTo-Json -Depth 6

    Write-CustomLog -Message (
        "Invoking Workflow (external IDs). WorkflowId='{0}', Devices={1}, Users={2}, HasParameters={3}" -f `
            $WorkflowId,
            ($Devices -join ','),
            ($Users   -join ','),
            [bool]($Parameters -and $Parameters.Count -gt 0)
    ) -Severity 'DEBUG'

    return Invoke-NxtApi -Type $apiType -Body $bodyJson -ReturnResponse
}
