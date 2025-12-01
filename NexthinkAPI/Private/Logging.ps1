function Initialize-Logger {
    [CmdletBinding()]
    param()

    # Prevent double-initialization if this gets called more than once
    if ($script:LoggerInitialized) {
        return
    }

    # Base script folder
    $script:ScriptFolder = $PSScriptRoot

    # Defaults
    $defaultLogFolder        = Join-Path -Path $script:ScriptFolder -ChildPath 'Logs'
    $defaultLogLevel         = 'INFO'
    $defaultRetentionDays    = 7
    $defaultLogFormat        = "[%{timestamp:+yyyy-MM-dd HH:mm:ss.fffffzzz}][%{level:-7}][%{caller}][%{lineno:3}] %{message}"
    $logConfig               = $null

    if ($script:Config -and $script:Config.Logging) {
        $logConfig = $script:Config.Logging
    }

    # Resolve log folder (config override > default)
    if ($logConfig -and $logConfig.Path) {
        $resolvedPath = $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($logConfig.Path)
        $script:LogsFolder = $resolvedPath
    }
    else {
        $script:LogsFolder = $defaultLogFolder
    }

    # Log level (config or default)
    if ($logConfig -and $logConfig.LogLevel) {
        $script:LogLevel = [string]$logConfig.LogLevel
    }
    else {
        $script:LogLevel = $defaultLogLevel
    }

    # Retention days (config or default)
    if ($logConfig -and $logConfig.LogRetentionDays) {
        $script:LogRetentionDays = [int]$logConfig.LogRetentionDays
    }
    else {
        $script:LogRetentionDays = $defaultRetentionDays
    }

    # Format is constant for now
    $script:LogFormat = $defaultLogFormat

    # File names
    $script:LogFileName = Join-Path -Path $script:LogsFolder -ChildPath 'NexthinkApi-%{+yyyyMMdd}.log'
    $script:ZipFileName = Join-Path -Path $script:LogsFolder -ChildPath 'NexthinkApi-RotatedLogs.zip'

    # Ensure log folder exists
    try {
        if (-not (Test-Path -LiteralPath $script:LogsFolder -PathType Container)) {
            [void](New-Item -Path $script:LogsFolder -ItemType Directory -Force -ErrorAction Stop)
        }
    }
    catch {
        throw "Error creating log folder at '$($script:LogsFolder)'. Details: $($_.Exception.Message)"
    }

    # Configure logging target (Logging module)
    try {
        Add-LoggingTarget -Name File -Configuration @{
            Path              = $script:LogFileName
            Encoding          = 'unicode'
            Level             = $script:LogLevel
            Format            = $script:LogFormat
            RotateAfterAmount = $script:LogRetentionDays
            RotateAmount      = 1
            CompressionPath   = $script:ZipFileName
        }

        # Caller scope 2 = log the function that called Write-Log/Write-CustomLog
        Set-LoggingCallerScope 2
    }
    catch {
        throw "Failed to initialize logging target. Details: $($_.Exception.Message)"
    }

    $script:LoggerInitialized = $true

    Write-CustomLog -Message ("Logging enabled. Folder: '{0}', Level: {1}" -f $script:LogsFolder, $script:LogLevel) -Severity 'DEBUG'
}

function Write-CustomLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$Severity = 'INFO'
    )

    Write-Log -Message $Message -Level $Severity

    if ($PSBoundParameters.ContainsKey('Verbose') -or $VerbosePreference -eq 'Continue') {
        Write-Verbose ("$Message")
    }
}