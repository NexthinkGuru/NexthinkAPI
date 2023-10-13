function Get-FormattedNqlOutput {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject]$Data
    )

    $headers = $Data.headers
    $dataRows = $Data.data
    $numColumns = $headers.count
    $Output=[system.collections.arraylist]@()

    foreach($row in $dataRows) {
        $rowHash=@{}
        for ($i=0; $i -lt $numColumns; $i++) { $rowHash.add($headers[$i],$row[$i]) }
        [void]$output.add($(New-Object -Type PSObject -Property $rowHash))
    }

    $Output
}