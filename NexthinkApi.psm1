# Forcing Tls1.2 to avoid SSL failures
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# LOGGING
New-Variable -Name 'SCRIPT_FOLDER' -Value $PSScriptRoot -Option ReadOnly -Scope Script -Force
New-Variable -Name 'LOGS_FOLDER' -Value "$SCRIPT_FOLDER\Logs\" -Option ReadOnly -Scope Script -Force
New-Variable -Name 'LOGFILE_NAME' -Value "$LOGS_FOLDER\NexthinkApi-%{+yyyyMMdd}.log" -Option ReadOnly -Scope Script -Force
New-Variable -Name 'ZIPFILE_NAME' -Value "$LOGS_FOLDER\NexthinkApi-RotatedLogs.zip" -Option ReadOnly -Scope Script -Force
New-Variable -Name 'LOG_FORMAT' -Value "[%{timestamp:+yyyy-MM-dd HH:mm:ss.fffffzzz}][%{level:-7}][%{lineno:3}] %{message}" -Option ReadOnly -Scope Script -Force
New-Variable -Name 'LOG_RETENTION_DAYS' -Value 7 -Option ReadOnly -Scope Script -Force
New-Variable -Name 'LOG_LEVEL' -Value 'INFO' -Option ReadOnly -Scope Script -Force

# Default Config File
New-Variable -name DEFAULT_CONFIG -Value 'config.json' -Scope Script -Force

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

New-Variable -Name BASE_API_RUNTIME -Option ReadOnly -Scope Script -Force -Value @{BASE = '';headers = $baseHeaders;expires = [DateTime]0}

# Logging
function Write-CustomLog ([string]$Message, [string]$Severity = 'INFO') {
    Write-Log -Message $Message -Level $Severity
}

function Initialize-Logger {
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
}

function Initialize-Folder ([string]$Path) {
    try {
        if (-not (Test-Path -Path $Path)) {
            [void](New-Item -Path $Path -ItemType 'Directory' -Force -ErrorAction Stop)
        }
    } catch {
        throw "Error creating folder at $Path."
    }
}

# Enrichment
function Invoke-EnrichmentRequest {
    <#
    .SYNOPSIS
        Enriches Nexthink Objects
    .DESCRIPTION
        PUTs data to the Nexthink Enrichment API endpoint for updating.
    .INPUTS
        None. This does not accept pipeline input.
    .OUTPUTS
        Object. 
    .NOTES
        This function is meant for use by other NxtAPI functions.
    #>
    [CmdletBinding()]
    param(
        # path of the request
        $path=$API_PATHS.ENRICHMENT,

        # the body of the request. This can be either json or a formatted form-data
        [parameter(Mandatory=$true)]
        [Alias('json','Enrichment')]
        $body
    )

    $uri = $CONFIG._API.BASE + $path
    $bodyJson = $body | ConvertTo-Json -Depth 8

    Set-Jwt

    $invokeParams = @{
        Uri = $uri
        Method = 'POST'
        Headers = $CONFIG._API.headers
        ContentType = 'application/json'
        Body = $bodyJson
    }

    try {
        $response = Invoke-RestMethod @invokeParams
        $responseJson = $response | ConvertFrom-Json $response
        if ($responseJson.status -ne 'success') {
            throw $reponseJson.errors
        }
    } catch [System.Net.WebException] {
        # A web error has occurred
        $StatusCode = $_.Exception.Response.StatusCode.Value__
        $Headerdetails = $_.Exception.Response.Headers
        $ThisException = $_.Exception
        $NexthinkMsgJson = $_
        $NexthinkMsg = $NexthinkMsgJson | ConvertFrom-Json
    
        switch ($StatusCode)
        {
            400 {
                # Bad Request
                $OutputObject = [PSCustomObject]@{
                    error = 400
                    'Path&Query' = $thisException.Response.ResponseUri.PathAndQuery
                    description = 'Bad request - invalid enrichment.'
                    Errors = $($NexthinkMsg.errors)
                }
                throw $OutputObject
            }

            401 {
                # Authentication Failure
                $OutputObject = [PSCustomObject]@{
                    error = 401
                    'Path&Query' = $thisException.Response.ResponseUri.PathAndQuery
                    description = "Unauthorized - invalid authentication credentials"
                    NexthinkCode = $($NexthinkMsg.code)
                    message = $($NexthinkMsg.message)
                }
                throw $OutputObject
            }

            403 {
                # Forbidden
                $OutputObject = [PSCustomObject]@{
                    error = 403
                    'Path&Query' = $thisException.Response.ResponseUri.PathAndQuery
                    description = "Forbidden - no permission to trigger enrichment"
                    NexthinkCode = $($NexthinkMsg.code)
                    message = $($NexthinkMsg.message)
                }                
                throw $OutputObject
            }

            # 429 {
            #     # Too many requests
            #     $WaitForSeconds = $Headerdetails['Retry-After']
            #     Write-Verbose "Waiting for $WaitForSeconds seconds..."
            #     Start-Sleep -second $WaitForSeconds
            #     $path = $ThisException.Response.ResponseUri.PathAndQuery.Replace("/api/v2/","") 
            #     Invoke-APIQuery -path $path -field $field -system $System                
            # }

            # 500 {
            #     $OutputObject = [PSCustomObject]@{
            #         error = 500
            #         'Path&Query' = $thisException.Response.ResponseUri.PathAndQuery
            #         description = "A Server Error occurred requesting '$uri'. Please verify the input fields before contacting Nexthink Support."
            #     }                
            #     throw $OutputObject                     
            # }

            default {
                throw
            }
        }

    } catch {
        throw $_
    }
}

function Get-FieldID{
    [CmdletBinding()]
    param (
        [Parameter()]
        [Alias('FieldName')]
        [ValidateNotNullOrEmpty()]
        [String]$Name
    )
    $table, $field = $Name.Split('.')
    -join ($table,'/',$table,'/',$field)
}

function New-SingleFieldEnrichment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidatePattern('^([A-z]*)\.(#[A-z]*)$')]
        [ValidateScript({[Int[]]($_.Split('.')).Count -eq 2})]
        [String]$FieldName,

        [Parameter(Mandatory=$true)]
        [ValidatePattern('^([A-z]*)\.([A-z]*)$')]
        [ValidateScript({[Int[]]($_.Split('.')).Count -eq 2})]
        [String]$ObjectName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [hashtable]$ObjectValues
    )
    $enrichments = [System.Collections.ArrayList]::new()

    $FieldId = Get-FieldID -Name $fieldName

    $ObjectId = $ENRICHMENT_IDS.$ObjectName
    if ($null -eq $ObjectId) {
        throw "Invalid Object Selection: $ObjectName.  Choose one of the following: $($ENRICHMENT_IDS.keys)"
    }

    foreach ($Object in $objectValueMap.Keys) {
        $identification = [PSCustomObject]@{
            name = $ObjectId
            value = $Object
        }
        $fields = [PSCustomObject]@{
            name = $FieldId
            value = $objectValueMap.$Object
        }
        $enrichments.Add([PSCustomObject]@{
            identification = @($identification)
            fields = @($fields)
        })
    }

    [PSCustomObject]@{
        enrichments = $enrichments
        domain = 'ps_custom_fields'
    }
}

# API Token Management
function Get-StringAsBase64 ([string]$InputString) {
    [CmdletBinding()]
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
    $EncodedText = [Convert]::ToBase64String($Bytes)
    return $EncodedText
}

function Get-ClientCredentials ([string]$Target) {
    [CmdletBinding()]
    $storedCredentials = Get-StoredCredential -Target $Target
    if ($storedCredentials -and $null -ne $storedCredentials.UserName -and $null -ne $storedCredentials.Password ) {
        $userName = $storedCredentials.UserName
        $securePassword = $storedCredentials.Password
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
        $unsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

        return @{ clientId = $userName; clientSecret = $unsecurePassword }
    } else {
        throw "Credentials not found or they are empty for Target: $Target"
    }
}

function Get-Jwt {
    <#
    .SYNOPSIS
        Retrieves the JWT from the API
    .DESCRIPTION
        Logs into the API Token endpoint and gets the JWT using the oauth credentials
    .INPUTS
        None. This does not accept pipeline input.
    .OUTPUTS
        token & expiration of token
    .NOTES
        This function is only meant for use within other Nexthink functions.
    #>
    [CmdletBinding()]
    
    $uri = $CONFIG._API.BASE + $API_PATHS.OAUTH

    # Invoke-WebRequests usually displays a progress bar. The $ProgressPreference variable determines whether this is displayed (default value = Continue)
    $ProgressPreference = 'SilentlyContinue'  
    try {
        $credentials = Get-ClientCredentials -Target $CONFIG.NexthinkAPI.OAuthCredentialEntry

        $basicHeader = Get-StringAsBase64 -InputString "$($credentials.clientId):$($credentials.clientSecret)"
        #$headers = New-Object "System.Collections.Generic.Dictionary[[string],[string]]"
        $headers = $BASE_API_RUNTIME.headers
        $headers.Authorization = "Basic " + $basicHeader

        $response = Invoke-WebRequest -Uri $uri -Method 'POST' -Headers $headers -UseBasicParsing
        if ($response.StatusCode -ne '200') {
            throw "Error sending request to get the JWT token with status code: $($response.StatusCode)"
        }

        $parsedResponse = ConvertFrom-Json $([String]::new($response.Content))
        $tokenDate = [DateTime]$response.Headers.Date
        @{token = $parsedResponse.access_token; expires = $tokenDate.AddSeconds($parsedResponse.expires_in)}
    } catch [net.webexception], [io.ioexception] {
        throw "Unable to access $($uri) Endpoint. Details: $($_.Exception.Message)"
    } catch {
        throw "An error occurred that could not be resolved. Details: $($_.Exception.Message)"
    }
    $ProgressPreference = 'Continue'
}

function Set-Jwt {
    <#
    .SYNOPSIS
        Checks JWT Expiration
    .DESCRIPTION
        Validates the Jwt won't expire in the next 60 seconds and asks for a new one if it will.
    .INPUTS
        None. This does not accept pipeline input.
    .OUTPUTS
        None.
    .NOTES
        This function is only meant for use within other Nexthink functions.
    #> 
    if ($CONFIG._API.expires.AddMinutes(1) -lt (Get-Date)) {        
        $localToken = Get-Jwt
        $CONFIG._API.expires = $localToken.expires
        Set-Headers -Token $localToken.token
    }
}

# API Management
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
        [String]$Path = $DEFAULT_CONFIG
    )

    # Retrieve the configuration json file
    New-Variable -Name CONFIG -Scope Script -Value $(Get-Content $Path | ConvertFrom-Json) -Force
    Add-Member -InputObject $CONFIG -MemberType NoteProperty -name _API -Value $BASE_API_RUNTIME -ErrorAction SilentlyContinue

    # Base URL for Infinity API Calls
    $CONFIG._API.BASE = "https://{0}.api.{1}.nexthink.cloud{2}" -f $CONFIG.NexthinkAPI.InstanceName, $CONFIG.NexthinkAPI.Region, $API_PATHS.BASE
    
    # Check and get the new Jwt if needed
    Set-Jwt
}

function Set-Headers {
    <#
    .SYNOPSIS
        Sets the current header API Values
    .DESCRIPTION
        Will create or update the headers for the Nexthink API Calls, adding a new TraceID for each header
    .INPUTS
        Token value from Get-JWT Call. This does not accept pipeline input.
    .OUTPUTS
        
    .NOTES
        Internal function only
        
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String]$Token
    )
    $CONFIG._API.headers.Authorization = "Bearer " + $Token
    $CONFIG._API.headers.'x-enrichment-trace-id' = ([guid]::NewGuid()).Guid
}

function Get-ApiConfig {
    $CONFIG._API
}

function Invoke-NexthinkAPI {
    # Placeholder for Single function to make Web request calls vs each sub-function
}

# Remote Action API
function Invoke-RemoteAction {
    <#
    .SYNOPSIS
        Triggers RA for devices
    .DESCRIPTION
        Triggers the execution of Remote Actions for 1 or more devivces
    .INPUTS
        RA ID
        List of device UID's
        Optional RA Parameters
        This does not accept pipeline input.
    .OUTPUTS
        Object. 
    .NOTES
    #>
    [CmdletBinding()]
    param(
        # path of the request
        $path=$API_PATHS.RA_EXEC,

        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$remoteActionId,

        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Array]$deviceIdList,
        
        [parameter(Mandatory=$false)]
        [hashtable]$Parameters
    )

    $uri = $CONFIG._API.BASE + $path

    $body = @{
        remoteActionId = $remoteActionId
        devices = $deviceIdList
    }
    # Build Add any optional dynamic parameters for the RA
    if (($null -ne $Parameters) -and ($Parameters.count -ge 1)) {
        $body.Add('params', $Parameters)
    }
    $bodyJson = $body | ConvertTo-Json -Depth 4

    Set-Jwt

    $invokeParams = @{
        Uri = $uri
        Method = 'POST'
        Headers = $CONFIG._API.headers
        ContentType = 'application/json'
        Body = $bodyJson
    }

    try {
        $response = Invoke-RestMethod @invokeParams
        $response
    } catch [System.Net.WebException] {
        # A web error has occurred
        $StatusCode = $_.Exception.Response.StatusCode.Value__
        $Headerdetails = $_.Exception.Response.Headers
        $ThisException = $_.Exception
        $NexthinkMsgJson = $_
        $NexthinkMsg = $NexthinkMsgJson | ConvertFrom-Json
    
        switch ($StatusCode)
        {
            400 {
                # Bad Request
                $OutputObject = [PSCustomObject]@{
                    error = 400
                    'Path&Query' = $thisException.Response.ResponseUri.PathAndQuery
                    description = 'Bad request - invalid enrichment.'
                    Errors = $($NexthinkMsg.errors)
                }
                throw $OutputObject
            }

            401 {
                # Authentication Failure
                $OutputObject = [PSCustomObject]@{
                    error = 401
                    'Path&Query' = $thisException.Response.ResponseUri.PathAndQuery
                    description = "Unauthorized - invalid authentication credentials"
                    NexthinkCode = $($NexthinkMsg.code)
                    message = $($NexthinkMsg.message)
                }
                throw $OutputObject
            }

            403 {
                # Forbidden
                $OutputObject = [PSCustomObject]@{
                    error = 403
                    'Path&Query' = $thisException.Response.ResponseUri.PathAndQuery
                    description = "Forbidden - no permission to trigger enrichment"
                    NexthinkCode = $($NexthinkMsg.code)
                    message = $($NexthinkMsg.message)
                }                
                throw $OutputObject
            }

            # 429 {
            #     # Too many requests
            #     $WaitForSeconds = $Headerdetails['Retry-After']
            #     Write-Verbose "Waiting for $WaitForSeconds seconds..."
            #     Start-Sleep -second $WaitForSeconds
            #     $path = $ThisException.Response.ResponseUri.PathAndQuery.Replace("/api/v2/","") 
            #     Invoke-APIQuery -path $path -field $field -system $System                
            # }

            # 500 {
            #     $OutputObject = [PSCustomObject]@{
            #         error = 500
            #         'Path&Query' = $thisException.Response.ResponseUri.PathAndQuery
            #         description = "A Server Error occurred requesting '$uri'. Please verify the input fields before contacting Nexthink Support."
            #     }                
            #     throw $OutputObject                     
            # }

            default {
                throw
            }
        }
    } catch {
        throw $_
    }
}

function Invoke-ListRemoteActions {
    <#
    .SYNOPSIS
        Lists available Remote Actions
    .DESCRIPTION
        Returns an object of RA's enabled for API Consumption
    .INPUTS
        Optional Remote Action ID. This does not accept pipeline input.
    .OUTPUTS
        Object.
    .NOTES
        ?hasScriptWindows=true&hasScriptMacOs=false
    #>
    [CmdletBinding()]
    param(
        # path of the request
        $path=$API_PATHS.RA_LIST,

        [parameter(Mandatory=$false)]
        [Alias('nqlId')]
        [string]$remoteActionId
    )

    $uri = $CONFIG._API.BASE + $path
    if ($null -ne $remoteActionId) {
        $remoteActionIdEncoded = [System.Web.HttpUtility]::UrlEncode($remoteActionId)
        $uri = -join ($uri,$API_PATHS.RA_DETAILS,$remoteActionIdEncoded)
    }

    Set-Jwt

    $invokeParams = @{
        Uri = $uri
        Method = 'GET'
        Headers = $CONFIG._API.headers
        ContentType = 'application/json'
    }

    try {
        $response = Invoke-RestMethod @invokeParams
    } catch [System.Net.WebException] {
        # A web error has occurred
        $StatusCode = $_.Exception.Response.StatusCode.Value__
        $Headerdetails = $_.Exception.Response.Headers
        $ThisException = $_.Exception
        $NexthinkMsgJson = $_
        $NexthinkMsg = $NexthinkMsgJson | ConvertFrom-Json
    
        switch ($StatusCode)
        {
            400 {
                # Bad Request
                $OutputObject = [PSCustomObject]@{
                    error = 400
                    'Path&Query' = $thisException.Response.ResponseUri.PathAndQuery
                    description = 'Bad request - invalid enrichment.'
                    Errors = $($NexthinkMsg.errors)
                }
                throw $OutputObject
            }

            401 {
                # Authentication Failure
                $OutputObject = [PSCustomObject]@{
                    error = 401
                    'Path&Query' = $thisException.Response.ResponseUri.PathAndQuery
                    description = "Unauthorized - invalid authentication credentials"
                    NexthinkCode = $($NexthinkMsg.code)
                    message = $($NexthinkMsg.message)
                }
                throw $OutputObject
            }

            403 {
                # Forbidden
                $OutputObject = [PSCustomObject]@{
                    error = 403
                    'Path&Query' = $thisException.Response.ResponseUri.PathAndQuery
                    description = "Forbidden - no permission to trigger enrichment"
                    NexthinkCode = $($NexthinkMsg.code)
                    message = $($NexthinkMsg.message)
                }                
                throw $OutputObject
            }

            # 429 {
            #     # Too many requests
            #     $WaitForSeconds = $Headerdetails['Retry-After']
            #     Write-Verbose "Waiting for $WaitForSeconds seconds..."
            #     Start-Sleep -second $WaitForSeconds
            #     $path = $ThisException.Response.ResponseUri.PathAndQuery.Replace("/api/v2/","") 
            #     Invoke-APIQuery -path $path -field $field -system $System                
            # }

            # 500 {
            #     $OutputObject = [PSCustomObject]@{
            #         error = 500
            #         'Path&Query' = $thisException.Response.ResponseUri.PathAndQuery
            #         description = "A Server Error occurred requesting '$uri'. Please verify the input fields before contacting Nexthink Support."
            #     }                
            #     throw $OutputObject                     
            # }

            default {
                throw
            }
        }
    } catch {
        throw $_
    }
    
    # Process through the responses, only returning the ones we want.
    if ($null -ne $remoteActionId) {
        foreach ($RA in $response) {
            if ($RA.targeting.apiEnabled) { $RA }
        } 
    } else { $response }
}


# Export modules we'll make available to all
Export-ModuleMember -Function Initialize-Enricher
Export-ModuleMember -Function Get-Config
Export-ModuleMember -Function *Enrichment
Export-ModuleMember -Function Invoke-EnrichmentRequest
Export-ModuleMember -Function Invoke-ListRemoteActions
Export-ModuleMember -Function Invoke-RemoteAction
