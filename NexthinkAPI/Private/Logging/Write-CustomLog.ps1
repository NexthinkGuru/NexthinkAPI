function Write-CustomLog ([string]$Message, [string]$Severity = 'INFO') {
    Write-Log -Message $Message -Level $Severity
}