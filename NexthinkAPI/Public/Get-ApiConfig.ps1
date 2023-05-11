function Get-ApiConfig {
    [CmdletBinding()]
    param ()
    if ($CONFIG._API) {
        $CONFIG._API
    } else {
        Write-Warning "No Config - Initialize the NexthinkAPI."
    }
    
}