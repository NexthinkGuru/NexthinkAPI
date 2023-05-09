function Write-CustomLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$Severity = 'INFO'
    )
    Write-Log -Message $Message -Level $Severity
}