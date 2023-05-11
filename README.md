# Nexthink API
This Powershell Module provides a serices of cmdlets for interacting with the Nexthink REST API and the Nexthink Infinity system

**NOTE:**  This is unoffical and not supported by Nexthink S.A.

## Requirements

Requires PowerShell 5.1 or above.
Requires PowerShell Module Credential Manager [PowerShell Gallery](https://www.powershellgallery.com/packages/CredentialManager/2.0) with `Install-Module CredentialManager`.

Requires PowerShell Module Logging [PowerShell Gallery](https://www.powershellgallery.com/packages/Logging/4.8.5) with `Install-Module Logging`.

## Usage

The NexthinkAPI module can be easily be installed from the [PowerShell Gallery](https://www.powershellgallery.com/packages/NexthinkAPI) with `Install-Module NexthinkAPI`.

### Obtain API Credentials

Log onto your Nexthink Instance, Select **Administration** from the main menu.  Click on **API credentials** in the navigation panel from the Account Management Section.

https://docs.nexthink.com/platform/latest/api-credentials

### Setting up stored credentials
On the system that will be running the NexthinkAPI, open PowerShell under the credentials of the local user who will run the commands.  If you aren't logged into the user already, you can use the runas command on the command line: runas /user:<service account> powershell.exe

runas CLI
In the newly opened PowerShell window, add the API credentials you just created in the Nexthink web interface by writing the following command:

`New-StoredCredential -Target "nxt-ctx-prod" -UserName <ClientID> -Password <ClientSecret> -Persist LocalMachine`

### Create Config file
  
  Save the configuration details in a config.json file.
  
  Sample
  ```Json
  {
    "Logging": {
        "LogRetentionDays": 7,
        "LogLevel": "INFO",
        "Path": "./Logs/"
    },
    "NexthinkAPI": {
        "InstanceName": "<customerInstanceName>",
        "Region": "<us/eu/ca/ap/...>",
        "OAuthCredentialEntry": "<Target name from stored credentials>",
        "RequestBatchSize": "1000"
    }
}
```
  
### Creating a new session

  Loads the configuration file, retrieves the secure credentials and obtains a Token for API Calls
  
```PowerShell
Initialize-NexthinkAPI
```
  
 ### Shows the configuration data used in the API Calls Used to validate the token
```PowerShell
Get-ApiConfig
```
  
### List the Remote Actions that are available to run via API
 ```PowerShell
  Invoke-ListRemoteActions
  ```

### Execute a remote action

  ```PowerShell
  # Setup for calling a basic RA.
  $remoteActionId = 'get_chrome_plugins'
  $deviceIdList = @('2bdb0941-2507-40de-854a-3efa1784b26b','d0debb1b-fc48-4eb1-81fa-8a799b21d108')
  Invoke-RemoteAction -remoteActionId $remoteActionId -deviceIdList $deviceIdList
  ```

### Create an enrichment object for a field on a given object table

  ```PowerShell
$fieldName  = 'device.#biosUpToDate'    # The name of the field we need to enrich
$objectIDName = 'device.name'             # The name of the field to be used to ID the object

$objectID_ValueMap = @{                   # hashtable of data values.
    'SENATORMARC' = 'duh2'
    'RAGH-BOX' = "Nope2"
}

# Create the enrichment variable to send to the enricher
$mySingleFieldEnrichment = New-SingleFieldEnrichment -fieldName $fieldName -objectName $objectIDName -ObjectValues $objectID_ValueMap
```
### Send an enrichment to be processed
```Powershell
# Now we can send it to the enricher
Invoke-EnrichmentRequest -Enrichment $mySingleFieldEnrichment
```

### Send a Campaign


## Authors
  
 - Current: [Pat Gudat](https://github.com/NexthinkGuru)
  
  
