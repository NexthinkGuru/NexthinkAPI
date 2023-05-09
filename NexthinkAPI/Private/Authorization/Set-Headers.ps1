function Set-Headers {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String]$Token
    )
    $CONFIG._API.headers.Authorization = "Bearer " + $Token
    $CONFIG._API.headers.'x-enrichment-trace-id' = ([guid]::NewGuid()).Guid
}