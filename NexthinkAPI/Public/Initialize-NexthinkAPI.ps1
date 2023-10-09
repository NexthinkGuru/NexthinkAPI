function Initialize-NexthinkAPI {
    <#
    .SYNOPSIS
        Reads in Config & Intitializes connection
    .DESCRIPTION
        Reads in the config.json, validating properties, & obtains the initial JWT
    .INPUTS
        Path to config file. This does not accept pipeline input.
    .OUTPUTS
    .NOTES
    #>
    [CmdletBinding()]
    param (
        [Alias("Config","ConfigPath","ConfigFile")]
        [Parameter()]
        [String]$Path = "$PWD\config.json"
    )

    # Check for config file
    if (! (Test-Path $Path)) {
        Write-Error "Unable to locate config file: $Path"
        break
    }

    # Forcing Tls1.2 to avoid SSL failures
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # base format of the information needed to run the API
    $baseHeaders = New-Object "System.Collections.Generic.Dictionary[[string],[string]]"
    $baseHeaders.Add("Content-Type", "application/json")
    $baseHeaders.Add("Accept", "application/json")
    $baseHeaders.Add("Authorization", "")
    # $baseHeaders.Add("nx-source", $null)
    
    # Retrieve the configuration json file
    New-Variable -Name CONFIG -Scope Script -Value $(Get-Content $Path | ConvertFrom-Json) -Force
    New-Variable -Name BASE_API -Option ReadOnly -Scope Script -Force -Value @{BASE = '';headers = $baseHeaders;expires = [DateTime]0}
    Add-Member -InputObject $Config -MemberType NoteProperty -name _API -Value $BASE_API -ErrorAction SilentlyContinue

    # Validate configuration
    $errorMessage = @()
    if ($null -eq $Config.NexthinkAPI) {
        $errorMessage += "Please ensure NexthinkAPI configuration is available in config file"
    } else {
        if ($null -eq $Config.NexthinkAPI.InstanceName) { $errorMessage += "Missing InstanceName in NexthinkAPI configuration"}
        if ($null -eq $Config.NexthinkAPI.Region) { $errorMessage += "Missing Region in NexthinkAPI configuration"}
        if ($null -eq $Config.NexthinkAPI.OAuthCredentialEntry) { $errorMessage += "Missing OAuthCredentialEntry Name in NexthinkAPI configuration"}
    }
    if ($errorMessage.Length -gt 0) {
        Write-Host $errorMessage -ForegroundColor Red
        break
    }

    # Start the logger
    Initialize-Logger

    # Base URL for Infinity API Calls
    $Config._API.BASE = "https://{0}.api.{1}.nexthink.cloud{2}" -f $Config.NexthinkAPI.InstanceName, $Config.NexthinkAPI.Region, $MAIN.APIs.BASE
    Write-CustomLog -Message "Base URL: $($Config._API.BASE)" -Severity 'DEBUG'

    # Ensure we have a JWT that's valid with headers set
    Set-Headers
}