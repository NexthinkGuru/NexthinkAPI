function Get-ApiConfig {
    [CmdletBinding()]
    param ()
    if ($Config._API) {
        $Config._API
    } else {
        Write-Warning "No Config - Initialize the NexthinkAPI."
    }
    
}