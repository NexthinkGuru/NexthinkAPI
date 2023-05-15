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
        Throw "Unable to locate config file: $Path"
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
    Add-Member -InputObject $CONFIG -MemberType NoteProperty -name _API -Value $BASE_API -ErrorAction SilentlyContinue

    # Base URL for Infinity API Calls
    $CONFIG._API.BASE = "https://{0}.api.{1}.nexthink.cloud{2}" -f $CONFIG.NexthinkAPI.InstanceName, $CONFIG.NexthinkAPI.Region, $MAIN.APIs.BASE
    Write-CustomLog -Message "Base URL: $($CONFIG._API.BASE)" -Severity 'DEBUG'
    
    # Start the logger
    Initialize-Logger

    # Ensure we have a JWT that's valid with headers set
    Set-Headers
}