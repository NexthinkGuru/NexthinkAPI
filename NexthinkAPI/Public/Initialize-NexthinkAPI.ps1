function Initialize-NexthinkAPI {
    <#
    .SYNOPSIS
        Initializes the Nexthink Infinity API configuration for this module.

    .DESCRIPTION
        Reads the specified JSON configuration file, validates required Nexthink
        API settings, configures security protocols and base API headers,
        initializes logging, performs a proxy sanity check, and obtains an initial
        JWT token so subsequent API calls can succeed.

        This function must be called before using other NexthinkAPI module commands
        that depend on the global $Config and $BASE_API state.

    .PARAMETER Path
        The path to the Nexthink API configuration file (JSON).

        - Defaults to: .\config.json in the current working directory.
        - Must point to an existing file.
        - The file must define at least:

            {
              "NexthinkAPI": {
                "InstanceName": "<your-instance>",
                "Region":       "<your-region>",
                "OAuthCredentialEntry": "<Windows Credential Manager entry name>"
              },
              "Proxy": {
                "UseSystemProxy": <true|false>,
                "UseDefaultCredentials": <true|false>
              },
              "Logging": {
                "LogLevel": "DEBUG",
                "LogRetentionDays": 7,
                "Path": "./Logs/"
              }
            }

        This parameter also honours the aliases: Config, ConfigPath, ConfigFile.

    .INPUTS
        None. This function does not accept pipeline input.

    .OUTPUTS
        None.

        On success, this function populates:
          - $script:Config   : Parsed configuration object (including ._API)
          - $script:BASE_API : Base URL, headers dictionary, and token expiry
        and establishes a valid JWT for immediate use by other API calls.

    .NOTES
        - Throws if the config file is missing or malformed.
        - Throws if required NexthinkAPI properties are missing:
              InstanceName, Region, OAuthCredentialEntry.
        - Logs:
            - The config file used (Verbose)
            - Base URL (DEBUG)
            - Proxy-related warnings if system proxy is configured but
              Proxy.UseSystemProxy = $false
            - Failure to obtain initial JWT (ERROR)
            - Successful initialization (INFO)

    .EXAMPLE
        Initialize-NexthinkAPI

        Uses .\config.json from the current directory, validates it,
        initializes logging, configures API state, and fetches an initial JWT.

    .EXAMPLE
        Initialize-NexthinkAPI -Path 'C:\Configs\Nexthink\nexthink-config.json'

        Uses the specified configuration file instead of the default.

    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $false,
            Position  = 0,
            ValueFromPipelineByPropertyName = $true
        )]
        [Alias("Config","ConfigPath","ConfigFile")]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if (-not (Test-Path -LiteralPath $_ -PathType Leaf)) {
                throw "Config file not found: $_"
            }
            $true
        })]
        [System.IO.FileInfo]$Path = "$PWD\config.json"
    )

    # Retrieve the configuration json file
    Write-Verbose "Using config file: $($Path.FullName)"
    $script:Config = Get-Content -LiteralPath $Path.FullName -Raw | ConvertFrom-Json

    # Configure the API settings and default headers
    Set-SecurityProtocol

    $baseHeaders = New-Object "System.Collections.Generic.Dictionary[[string],[string]]"
    $baseHeaders.Add("Authorization", "")

    $script:BASE_API = @{
        BASE    = ''
        headers = $baseHeaders
        expires = [DateTime]0
    }
    Set-Variable -Name BASE_API -Scope Script -Option ReadOnly -Force
    $Config | Add-Member -NotePropertyName _API -NotePropertyValue $script:BASE_API -Force

    # Validate configuration
    $errorMessage = @()

    if ($null -eq $script:Config.NexthinkAPI) {
        $errorMessage += "Please ensure NexthinkAPI configuration is available in config file"
    }
    else {
        if ([string]::IsNullOrWhiteSpace($script:Config.NexthinkAPI.InstanceName)) {
            $errorMessage += "Missing InstanceName in NexthinkAPI configuration"
        }

        if ([string]::IsNullOrWhiteSpace($script:Config.NexthinkAPI.Region)) {
            $errorMessage += "Missing Region in NexthinkAPI configuration"
        }

        if ([string]::IsNullOrWhiteSpace($script:Config.NexthinkAPI.OAuthCredentialEntry)) {
            $errorMessage += "Missing OAuthCredentialEntry Name in NexthinkAPI configuration"
        }
    }

    if ($errorMessage.Count -gt 0) {
        throw ($errorMessage -join [Environment]::NewLine)
    }

    Initialize-Logger

    # Base URL for Infinity API Calls
    $script:Config._API.BASE = "https://{0}.api.{1}.nexthink.cloud{2}" -f `
        $script:Config.NexthinkAPI.InstanceName, `
        $script:Config.NexthinkAPI.Region, `
        $MAIN.APIs.BASE
    Write-CustomLog -Message "Base URL: $($script:Config._API.BASE)" -Severity 'DEBUG'

    # Proxy configuration sanity check
    try {
        if ($script:Config.Proxy -and -not $script:Config.Proxy.UseSystemProxy) {
            # See if Windows has any proxy configured for outbound HTTPS
            $systemProxy = [System.Net.WebRequest]::GetSystemWebProxy()

            if ($systemProxy) {
                # Dummy URI just to query proxy rules; no network call is made here
                $testUri  = [Uri]$script:Config._API.BASE
                $proxyUri = $systemProxy.GetProxy($testUri)

                # If GetProxy returns something other than the original URI,
                # a proxy is configured for this kind of request.
                if ($proxyUri -and $proxyUri.AbsoluteUri -ne $testUri.AbsoluteUri) {
                    $message = "System proxy is configured for outbound HTTPS ({0}), " +
                               "but Proxy.UseSystemProxy is set to false in config.json. " +
                               "If your Nexthink endpoints are only reachable via this " +
                               "corporate proxy, API calls may fail until you enable " +
                               "Proxy.UseSystemProxy." -f $proxyUri.AbsoluteUri
                    Write-CustomLog -Message $message -Severity 'WARNING'
                }
            }
        }
    }
    catch {
        # Don't blow up init just because proxy inspection failed
        Write-CustomLog -Message ("Unable to inspect system proxy configuration. Details: {0}" -f $_.Exception.Message) -Severity 'DEBUG'
    }

    # Ensure we have a JWT that's valid with headers set
    try {
        Set-Headers
    }
    catch {
        Write-CustomLog -Message "Failed to obtain initial JWT during initialization. Details: $($_.Exception.Message)" -Severity 'ERROR'
        throw
    }

    Write-CustomLog -Message "NexthinkAPI initialized successfully" -Severity "INFO"
}
