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