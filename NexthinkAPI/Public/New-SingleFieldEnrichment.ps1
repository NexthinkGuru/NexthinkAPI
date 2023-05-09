function New-SingleFieldEnrichment {
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
        throw "Invalid Object Selection: $ObjectName.  Choose one of the following: $($ENRICHMENT_IDS.keys)"
    }

    foreach ($Object in $objectValueMap.Keys) {
        $identification = [PSCustomObject]@{
            name = $ObjectId
            value = $Object
        }
        $fields = [PSCustomObject]@{
            name = $FieldId
            value = $objectValueMap.$Object
        }
        $enrichments.Add([PSCustomObject]@{
            identification = @($identification)
            fields = @($fields)
        })
    }

    [PSCustomObject]@{
        enrichments = $enrichments
        domain = 'ps_custom_fields'
    }
}