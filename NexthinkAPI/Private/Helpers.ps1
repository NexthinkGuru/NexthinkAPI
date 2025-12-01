function Get-StringAsBase64 ([string]$InputString) {
    [CmdletBinding()]
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
    $EncodedText = [Convert]::ToBase64String($Bytes)
    return $EncodedText
}

function Get-FieldID{
    [CmdletBinding()]
    param (
        [Parameter()]
        [Alias('FieldName')]
        [ValidateNotNullOrEmpty()]
        [String]$Name
    )
    $table, $field = $Name.Split('.')
    -join ($table,'/',$table,'/',$field)
}