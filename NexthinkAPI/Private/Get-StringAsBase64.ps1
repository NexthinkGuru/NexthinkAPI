function Get-StringAsBase64 ([string]$InputString) {
    [CmdletBinding()]
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
    $EncodedText = [Convert]::ToBase64String($Bytes)
    return $EncodedText
}