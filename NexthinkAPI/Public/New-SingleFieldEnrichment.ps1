function New-SingleFieldEnrichment {
    [OutputType([PSCustomObject])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidatePattern('^([A-z]*)\.(#[A-z]*)$')]
        [ValidateScript({[Int[]]($_.Split('.')).Count -eq 2})]
        [String]$FieldName,

        [Parameter(Mandatory=$true)]
        [ValidatePattern('^([A-z]*)\.([A-z]*)$')]
        [ValidateScript({[Int[]]($_.Split('.')).Count -eq 2})]
        [String]$ObjectName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [hashtable]$ObjectValues
    )
    $enrichments = [System.Collections.ArrayList]::new()

    $fieldId = Get-FieldID -Name $fieldName

    $objectId = $MAIN.EnrichmentIDMap.$ObjectName
    if ($null -eq $objectId) {
        $message = "Invalid Object Selection: $ObjectName"
        Write-CustomLog $message -Severity "ERROR"
        throw $message
    }
    
    Write-CustomLog -Message "Enriching Field $fieldId of $objectId " -Severity "DEBUG"
    foreach ($Object in $ObjectValues.Keys) {
        Write-CustomLog -Message "Adding ${Object}:$($ObjectValues.$Object)" -Severity "DEBUG"
        $identification = [PSCustomObject]@{
            name = $objectId
            value = $Object
        }
        $fields = [PSCustomObject]@{
            name = $fieldId
            value = $ObjectValues.$Object
        }
        $enrichments.Add([PSCustomObject]@{
            identification = @($identification)
            fields = @($fields)
        }) | Out-Null
    }

    [PSCustomObject]@{
        enrichments = $enrichments
        domain = 'ps_custom_fields'
    }
    return
}