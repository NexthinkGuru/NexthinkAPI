# Nexthink API
This Powershell Module provides a serices of cmdlets for interacting with the Nexthink REST API and the Nexthink Infinity system

**NOTE:**  This is unoffical and not supported by Nexthink S.A.

## Requirements

Requires PowerShell 5.1 or above.

The Credential Manager module should be installed from the [PowerShell Gallery](https://www.powershellgallery.com/packages/CredentialManager/2.0) with `Install-Module CredentialManager`.

## Usage

The NexthinkAPI module should be installed from the [PowerShell Gallery](https://www.powershellgallery.com/packages/Nexthink) with `Install-Module Nexthink`.

### Obtain API Credentials

Log onto your Nexthink Instance, Select **Administration** from the main menu.  Click on **API credentials** in the navigation panel from the Account Management Section.

https://docs.nexthink.com/platform/latest/api-credentials

### Setting up stored credentials
On the system that will be running the NexthinkAPI, open PowerShell under the credentials of the local user who will run the commands.  If you aren't logged into the user already, you can use the runas command on the command line: runas /user:<service account> powershell.exe

runas CLI
In the newly opened PowerShell window, add the API credentials you just created in the Nexthink web interface by writing the following command:

`New-StoredCredential -Target "nxt-ctx-prod" -UserName <ClientID> -Password <ClientSecret> -Persist LocalMachine`

### Updating Config file
  
  Save the configuration details in a config.json file.
  
  e.g.
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
  
 ### Shows the configuration data used in the API Calls Used to validate the config
```PowerShell
Get-ApiConfig
```
  
### List the Remote Actions that are available to run via API
 ```PowerShell
  Invoke-ListRemoteActions
  ```

### Run a remote action

  ```PowerShell
  Invoke-RemoteAction -remoteActionId $remoteActionId -deviceIdList $deviceIdList
  ```
  
## Authors
  
 - Current: [Pat Gudat](https://github.com/NexthinkGuru)
  
  
