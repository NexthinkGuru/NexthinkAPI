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

    $FieldId = Get-FieldID -Name $fieldName

    $ObjectId = $ENRICHMENT_IDS.$ObjectName
    if ($null -eq $ObjectId) {
        Write-CustomLog "Invalid Object Selection: $ObjectName.  Choose one of the following: $($ENRICHMENT_IDS.keys)" -Severity "ERROR"
        throw "Invalid Object Selection: $ObjectName.  Choose one of the following: $($ENRICHMENT_IDS.keys)"
    }
    
    Write-CustomLog -Message "Enriching Field $FieldId of $ObjectId " -Severity "DEBUG"
    foreach ($Object in $ObjectValues.Keys) {
        Write-CustomLog -Message "Adding ${Object}:$($ObjectValues.$Object)" -Severity "DEBUG"
        $identification = [PSCustomObject]@{
            name = $ObjectId
            value = $Object
        }
        $fields = [PSCustomObject]@{
            name = $FieldId
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