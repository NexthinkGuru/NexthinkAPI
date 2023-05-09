# Sample data

# Requires -Module NexthinkApi
# Import-Module ".\NexthinkAPI\NexthinkApi.psm1"

# Will read in the Configuration file (optionally passed or default config.json) and get a Token for API Calls
Initialize-NexthinkAPI -Config "C:\Users\pgudat\OneDrive - Nexthink SA\Development\Infinity\GIT\NexthinkAPI\Sample\config.json"

# Shows the configuration data used in the API Calls Used to validate the config
# Get-ApiConfig

# # #
# Data Enricher API
$fieldName  = 'device.#biosUpToDate'    # The name of the field we need to enrich
$objectName = 'device.name'             # The name of the field to be used to ID the object

$objectValueMap = @{                   # hashtable of data values.
    'SENATORMARC' = 'duh2'
    'RAGH-BOX' = "Nope2"
}

# Create the enrichment variable to send to the enricher
$mySingleFieldEnrichment = New-SingleFieldEnrichment -fieldName $fieldName -objectName $objectName -ObjectValues $objectValueMap

# Now we can send it to the enricher
Invoke-EnrichmentRequest -Enrichment $mySingleFieldEnrichment

# # # 
# Remote Action API
#
# List the RA's that are available to run via API
$remoteActionList = Invoke-ListRemoteActions

# Setup for calling a basic RA.
$remoteActionId = 'get_chrome_plugins'

# Get the details of a single RA
$remoteActionDetails = Invoke-ListRemoteActions -remoteActionId $remoteActionId

# How to get the collector ID on an endpoint
$UID_REG_PATH = "HKLM:\SYSTEM\CurrentControlSet\Services\Nexthink Coordinator\params"
$UID_REG_PARAM = "uid"
$collectorUID = ((Get-ItemProperty -Path $UID_REG_PATH -Name $UID_REG_PARAM).$UID_REG_PARAM -split '/')[1]
$deviceIdList = @($collectorUID)

# Example list of ID's format
#$deviceIdList = @('id1','id2','...','idN') # An Array of ID's

# hashtable of parameters to send RA (if needed)
# $optionalParameterMap = @{                   
#     param1 = 'duh'
#     param2 = 'doh'
# }

Invoke-RemoteAction -remoteActionId $remoteActionId -deviceIdList $deviceIdList

