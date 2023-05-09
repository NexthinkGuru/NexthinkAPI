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
        [ValidateScript({Test-Path $_})]
        [String]$Path = './config.json'
    )

    # Forcing Tls1.2 to avoid SSL failures
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # API paths
    New-Variable -Name API_PATHS -Option ReadOnly -Scope Script -Force `
                -Value @{BASE = '/api/v1'
                        OAUTH = '/token'
                        RA_EXEC = '/act/execute'
                        RA_LIST = '/act/remote-action'
                        RA_DETAILS = '/details?nql-id='
                        ENRICHMENT = '/enrichment/data/fields'}

    # Enrichment Values Accepted
    New-Variable -Name ENRICHMENT_IDS -Option ReadOnly -Scope Script -Force `
                -Value @{'device.name' = 'device/device/name'
                        'device.uid'  = 'device/device/uid'
                        'user.sid'    = 'user/user/sid'
                        'user.uid'    = 'user/user/uid'
                        'binary.uid'  = 'binary/binary/uid'
                        'package.uid' = 'package/package/uid'}

    # base format of the information needed to run the API
    $baseHeaders = New-Object "System.Collections.Generic.Dictionary[[string],[string]]"
    $baseHeaders.Add("Content-Type", "application/json")
    $baseHeaders.Add("Accept", "application/json")
    $baseHeaders.Add("Authorization", "")
    $baseHeaders.Add("x-enrichment-trace-id", "0")
    $baseHeaders.Add("nx-source", $null)
    
    New-Variable -Name BASE_API -Option ReadOnly -Scope Script -Force -Value @{BASE = '';headers = $baseHeaders;expires = [DateTime]0}

    # Retrieve the configuration json file
    New-Variable -Name CONFIG -Scope Script -Value $(Get-Content $Path | ConvertFrom-Json) -Force
    Add-Member -InputObject $CONFIG -MemberType NoteProperty -name _API -Value $BASE_API -ErrorAction SilentlyContinue

    # Start the logger
    Initialize-Logger

    # Base URL for Infinity API Calls
    $CONFIG._API.BASE = "https://{0}.api.{1}.nexthink.cloud{2}" -f $CONFIG.NexthinkAPI.InstanceName, $CONFIG.NexthinkAPI.Region, $API_PATHS.BASE
    
    # Check and get the new Jwt if needed
    Set-Jwt
}