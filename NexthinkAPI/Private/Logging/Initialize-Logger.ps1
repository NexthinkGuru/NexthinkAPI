function Initialize-Logger {
    New-Variable -Name 'SCRIPT_FOLDER' -Value $PSScriptRoot -Option ReadOnly -Scope Script -Force
    New-Variable -Name 'LOGS_FOLDER' -Value "$SCRIPT_FOLDER\Logs\" -Scope Script -Force
    New-Variable -Name 'LOG_FORMAT' -Value "[%{timestamp:+yyyy-MM-dd HH:mm:ss.fffffzzz}][%{level:-7}][%{caller}][%{lineno:3}] %{message}" -Option ReadOnly -Scope Script -Force
    New-Variable -Name 'LOG_RETENTION_DAYS' -Value 7 -Scope Script -Force
    New-Variable -Name 'LOG_LEVEL' -Value 'INFO' -Scope Script -Force

    if ($CONFIG.Logging.LogLevel) { $LOG_LEVEL = $CONFIG.Logging.LogLevel }
    if ($CONFIG.Logging.LogRetentionDays) { $LOG_RETENTION_DAYS = [Int]$CONFIG.Logging.LogRetentionDays }
    if ($CONFIG.Logging.Path) { $LOGS_FOLDER = $CONFIG.Logging.Path }

    New-Variable -Name 'LOGFILE_NAME' -Value "$LOGS_FOLDER\NexthinkApi-%{+yyyyMMdd}.log" -Option ReadOnly -Scope Script -Force
    New-Variable -Name 'ZIPFILE_NAME' -Value "$LOGS_FOLDER\NexthinkApi-RotatedLogs.zip" -Option ReadOnly -Scope Script -Force

    try {
        if (-not (Test-Path -Path $LOGS_FOLDER)) {
            [void](New-Item -Path $LOGS_FOLDER -ItemType 'Directory' -Force -ErrorAction Stop)
        }
    } catch {
        throw "Error creating folder at $LOGS_FOLDER."
    }

    Add-LoggingTarget -Name File -Configuration @{
        Path              = $LOGFILE_NAME
        Encoding          = 'unicode'
        Level             = $LOG_LEVEL
        Format            = $LOG_FORMAT
        RotateAfterAmount = $LOG_RETENTION_DAYS
        RotateAmount      = 1
        CompressionPath   = $ZIPFILE_NAME
    }
    Set-LoggingCallerScope 2
    
    Write-CustomLog -Message "Logging Enabled - Log Level: INFO" -Severity 'INFO'
}