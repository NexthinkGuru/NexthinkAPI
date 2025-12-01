function New-SingleFieldEnrichment {
    <#
    .SYNOPSIS
        Builds a single-field Nexthink enrichment payload.

    .DESCRIPTION
        Creates a properly structured enrichment request object suitable for
        Invoke-EnrichmentRequest. This function:

        - Accepts a friendly object selector (ObjectName), such as "device.uid"
        - Accepts a friendly field selector (FieldName), such as "user.ad.city"
            or "device.#custom_field"
        - Maps both to the corresponding full Nexthink enrichment paths, e.g.:
                device.uid        -> device/device/uid
                user.ad.city      -> user/user/ad/city
                user.#cost_center -> user/user/#cost_center
        - Builds one enrichment entry per key/value pair in ObjectValues

        The resulting object can be passed directly into Invoke-EnrichmentRequest.

    .PARAMETER FieldName
        The enrichment field to update, specified using a short, friendly syntax.

        Fixed device virtualization fields (examples):
            device.configuration_tag
            device.virtualization.desktop_broker
            device.virtualization.desktop_pool
            device.virtualization.disk_image
            device.virtualization.environment_name
            device.virtualization.hostname
            device.virtualization.hypervisor_name
            device.virtualization.instance_size
            device.virtualization.last_update
            device.virtualization.region
            device.virtualization.type

        Fixed user AD fields (examples):
            user.ad.city
            user.ad.country_code
            user.ad.department
            user.ad.distinguished_name
            user.ad.email_address
            user.ad.full_name
            user.ad.job_title
            user.ad.last_update
            user.ad.office
            user.ad.organizational_unit
            user.ad.username

        Supported custom field patterns:
            device.#<custom_field_name>             -> device/device/#<custom_field_name>
            user.#<custom_field_name>               -> user/user/#<custom_field_name>
            binary.#<custom_field_name>             -> binary/binary/#<custom_field_name>
            package.#<custom_field_name>            -> package/package/#<custom_field_name>
            user.organization.#<custom_field_name>  -> user/user/organization/#<custom_field_name>

        Examples:
            device.virtualization.region
            user.ad.department
            device.#image_channel
            user.#cost_center
            user.organization.#region

    .PARAMETER ObjectName
        A friendly shorthand identifier for the Nexthink object you want to enrich.
        This is automatically mapped to the correct full object path.

        Valid values:
            device.name   -> device/device/name
            device.uid    -> device/device/uid
            user.sid      -> user/user/sid
            user.uid      -> user/user/uid
            user.upn      -> user/user/upn
            binary.uid    -> binary/binary/uid
            package.uid   -> package/package/uid

        Examples:
            device.uid
            user.upn
            package.uid

    .PARAMETER ObjectValues
        A hashtable where each key is the identifier for the target object
        (for example: device UID, user SID, user UPN, package UID) and each value
        is the enrichment value to assign to the specified FieldName.

        One enrichment entry is created for each key/value pair.

        Examples (for ObjectName 'user.sid'):
            @{
                'S-1-5-21-1234567890-1234567890-1234567890-1001' = 'IT'
                'S-1-5-21-1234567890-1234567890-1234567890-1002' = 'Finance'
            }

        Examples (for ObjectName 'device.uid'):
            @{
                '3fa85f64-5717-4562-b3fc-2c963f66afa6' = 'VDI-Pool-01'
                '0e8a9a54-9fd8-4e9a-83f4-4d611f9d1234' = 'VDI-Pool-02'
            }

    .OUTPUTS
        [PSCustomObject]

        Returns a PSCustomObject with the shape:

            @{
                enrichments = <array of enrichment items>
                domain      = 'ps_custom_fields'
            }

        This object is designed to be passed directly to Invoke-EnrichmentRequest
        as the -Enrichment parameter.

    .NOTES
        This function does not call the Nexthink API by itself.
        Use Invoke-EnrichmentRequest to send the generated payload to the
        Nexthink Enrichment API endpoint.

    .EXAMPLE
        $values = @{
            '3fa85f64-5717-4562-b3fc-2c963f66afa6' = 'Region-East'
            '0e8a9a54-9fd8-4e9a-83f4-4d611f9d1234' = 'Region-West'
        }

        $payload = New-SingleFieldEnrichment `
            -FieldName  'device.virtualization.region' `
            -ObjectName 'device.uid' `
            -ObjectValues $values

        Invoke-EnrichmentRequest -Enrichment $payload

    .EXAMPLE
        $values = @{
            'S-1-5-21-1234567890-1234567890-1234567890-1001' = 'IT'
            'S-1-5-21-1234567890-1234567890-1234567890-1002' = 'Finance'
        }

        $payload = New-SingleFieldEnrichment `
            -FieldName  'user.ad.department' `
            -ObjectName 'user.sid' `
            -ObjectValues $values

        Invoke-EnrichmentRequest -Enrichment $payload

    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        # Field name (friendly shorthand) – mapped to the full enrichment path.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FieldName,

        # Object name (friendly shorthand) – we map this to the full enrichment ID
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet(
            'device.name',
            'device.uid',
            'user.sid',
            'user.uid',
            'user.upn',
            'binary.uid',
            'package.uid'
        )]
        [string]$ObjectName,

        # Hashtable of object identifier -> field value
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if ($_.Count -eq 0) {
                throw "ObjectValues must contain at least one key/value pair."
            }
            $true
        })]
        [hashtable]$ObjectValues
    )

    # ----------------------------------------------------------------
    # Map friendly ObjectName to full enrichment object IDs
    # ----------------------------------------------------------------
    $objectMap = @{
        'device.name'   = 'device/device/name'
        'device.uid'    = 'device/device/uid'
        'user.sid'      = 'user/user/sid'
        'user.uid'      = 'user/user/uid'
        'user.upn'      = 'user/user/upn'
        'binary.uid'    = 'binary/binary/uid'
        'package.uid'   = 'package/package/uid'
    }

    # ----------------------------------------------------------------
    # Map friendly FieldName to full enrichment field path
    # ----------------------------------------------------------------
    $fixedFieldMap = @{
        # Device fields
        'device.configuration_tag'                 = 'device/device/configuration_tag'
        'device.virtualization.desktop_broker'     = 'device/device/virtualization/desktop_broker'
        'device.virtualization.desktop_pool'       = 'device/device/virtualization/desktop_pool'
        'device.virtualization.disk_image'         = 'device/device/virtualization/disk_image'
        'device.virtualization.environment_name'   = 'device/device/virtualization/environment_name'
        'device.virtualization.hostname'           = 'device/device/virtualization/hostname'
        'device.virtualization.hypervisor_name'    = 'device/device/virtualization/hypervisor_name'
        'device.virtualization.instance_size'      = 'device/device/virtualization/instance_size'
        'device.virtualization.last_update'        = 'device/device/virtualization/last_update'
        'device.virtualization.region'             = 'device/device/virtualization/region'
        'device.virtualization.type'               = 'device/device/virtualization/type'

        # User AD fields
        'user.ad.city'                  = 'user/user/ad/city'
        'user.ad.country_code'          = 'user/user/ad/country_code'
        'user.ad.department'            = 'user/user/ad/department'
        'user.ad.distinguished_name'    = 'user/user/ad/distinguished_name'
        'user.ad.email_address'         = 'user/user/ad/email_address'
        'user.ad.full_name'             = 'user/user/ad/full_name'
        'user.ad.job_title'             = 'user/user/ad/job_title'
        'user.ad.last_update'           = 'user/user/ad/last_update'
        'user.ad.office'                = 'user/user/ad/office'
        'user.ad.organizational_unit'   = 'user/user/ad/organizational_unit'
        'user.ad.username'              = 'user/user/ad/username'
    }

    # Resolve object ID from the friendly ObjectName
    $objectId = $objectMap[$ObjectName]
    if ([string]::IsNullOrWhiteSpace($objectId)) {
        $validObjects = ($objectMap.Keys -join ', ')
        $message = "Invalid ObjectName '$ObjectName'. Valid values are: $validObjects"
        Write-CustomLog -Message $message -Severity 'ERROR'
        throw $message
    }

    # Resolve FieldName to full field path
    $fullFieldName = $null

    if ($fixedFieldMap.ContainsKey($FieldName)) {
        $fullFieldName = $fixedFieldMap[$FieldName]
    }
    else {
        # Handle custom field patterns
        # device.#custom, user.#custom, binary.#custom, package.#custom, user.organization.#custom
        if ($FieldName -match '^device\.#([A-Za-z0-9_]+)$') {
            $fullFieldName = "device/device/#$($matches[1])"
        }
        elseif ($FieldName -match '^user\.#([A-Za-z0-9_]+)$') {
            $fullFieldName = "user/user/#$($matches[1])"
        }
        elseif ($FieldName -match '^binary\.#([A-Za-z0-9_]+)$') {
            $fullFieldName = "binary/binary/#$($matches[1])"
        }
        elseif ($FieldName -match '^package\.#([A-Za-z0-9_]+)$') {
            $fullFieldName = "package/package/#$($matches[1])"
        }
        elseif ($FieldName -match '^user\.organization\.#([A-Za-z0-9_]+)$') {
            $fullFieldName = "user/user/organization/#$($matches[1])"
        }
        else {
            $validFixed = $fixedFieldMap.Keys | Sort-Object
            $validPatterns = @(
                'device.#<custom_field_name>',
                'user.#<custom_field_name>',
                'binary.#<custom_field_name>',
                'package.#<custom_field_name>',
                'user.organization.#<custom_field_name>',
                'user.ad.<field_name>'  # e.g. user.ad.city, user.ad.department
            )

            $message = @()
            $message += "Invalid FieldName '$FieldName'."
            $message += "Accepted fixed values include (examples):"
            $message += "  " + ($validFixed -join ", ")
            $message += "Supported patterns:"
            foreach ($p in $validPatterns) {
                $message += "  $p"
            }

            $final = $message -join [Environment]::NewLine
            Write-CustomLog -Message $final -Severity 'ERROR'
            throw $final
        }
    }

    # At this point we have a full field path like device/device/... or user/user/...
    $fieldId = Get-FieldID -Name $fullFieldName

    # Use a strongly-typed list for enrichment items
    $enrichments = [System.Collections.Generic.List[object]]::new()

    Write-CustomLog -Message (
        "Enriching field '{0}' (path: '{1}') of object '{2}' with {3} value(s)" -f `
            $fieldId,
            $fullFieldName,
            $objectId,
            $ObjectValues.Count
    ) -Severity 'DEBUG'

    foreach ($objectKey in $ObjectValues.Keys) {
        $objectValue = $ObjectValues[$objectKey]

        Write-CustomLog -Message ("Adding {0}: {1}" -f $objectKey, $objectValue) -Severity 'DEBUG'

        $identification = [PSCustomObject]@{
            name  = $objectId
            value = $objectKey
        }

        $fields = [PSCustomObject]@{
            name  = $fieldId
            value = $objectValue
        }

        $enrichments.Add(
            [PSCustomObject]@{
                identification = @($identification)
                fields         = @($fields)
            }
        ) | Out-Null
    }

    return [PSCustomObject]@{
        enrichments = $enrichments
        domain      = 'ps_custom_fields'
    }
}
