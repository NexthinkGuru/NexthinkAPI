# NexthinkAPI PowerShell Module

This PowerShell module provides a set of robust, production-ready cmdlets for interacting with the **Nexthink Infinity APIs**, including Remote Actions, Workflows, Campaigns, NQL Queries, Exports, and Enrichment operations.

> **Note:** This is an **unofficial** community-developed module and is **not supported by Nexthink S.A.**

---

## 📦 Requirements

### PowerShell
- Windows PowerShell **5.1** or **PowerShell 7+**

### Required Modules
Install the prerequisites:

```powershell
Install-Module CredentialManager -Scope CurrentUser
Install-Module Logging -Scope CurrentUser
```

---

## 📥 Installation

Install the module from the PowerShell Gallery:

```powershell
Install-Module NexthinkAPI -Scope CurrentUser
```

---

## 🔐 Authentication & Credentials

### 1️⃣ Create API Credentials in Nexthink
Navigate to:

**Administration → API Credentials**
Documentation: https://docs.nexthink.com/platform/latest/api-credentials

### 2️⃣ Store the Credentials Locally
Run in PowerShell under the service/user account that will execute the module:

```powershell
Import-Module CredentialManager

# Pop a secure credential prompt
$cred = Get-Credential -UserName '<ClientID>' -Message 'Enter the Client Secret'

New-StoredCredential -Target 'nxt-prod' -UserName $cred.UserName `
    -Password ($cred.GetNetworkCredential().Password) -Persist LocalMachine
```

---

## ⚙️ Configuration

Create a `config.json` file and populate the attributes as shown below:

```json
{
  "NexthinkAPI": {
    "InstanceName": "<your-instance>",
    "Region": "<your-region>",
    "OAuthCredentialEntry": "<Windows Credential Manager entry name>"
  },
  "Proxy": {
    "UseSystemProxy": true,
    "UseDefaultCredentials": false
  },
  "Logging": {
    "LogLevel": "INFO",
    "LogRetentionDays": 7,
    "Path": "./Logs/"
  }
}

```

The Proxy section is used if you need to use a Web Proxy to access the internet. The system will attempt to use the System Proxy and pass default credentials if enabed.

The LogLevel Options are as follows:
- DEBUG
- INFO
- WARN
- ERROR
- FATAL

---

## 🚀 Initialize API Session

```powershell
# Load config.json from current directory
Initialize-NexthinkAPI

# Or specify a custom configuration file
Initialize-NexthinkAPI -Path .\config\dev_instance.json
```

View loaded configuration:

```powershell
Get-ApiConfig
```

---

# 📘 Module Functionality

## 🔧 Remote Actions

### List Remote Actions available via API

```powershell
Invoke-ListRemoteActions               # API-enabled RA only
Invoke-ListRemoteActions -Targeting all
Invoke-ListRemoteActions -RemoteActionId "#my_remote_action"
```

### Execute a Remote Action

```powershell
$actionId = "#get_chrome_plugins"
$devices  = @(
  "2bdb0941-2507-40de-854a-3efa1784b26b",
  "d0debb1b-fc48-4eb1-81fa-8a799b21d108"
)

Invoke-RemoteAction -RemoteActionId $actionId -Devices $devices
```

---

## 🧩 Data Enrichment

### Build an enrichment object

```powershell
$field = "device.#biosUpToDate"
$obj   = "device.name"
$values = @{
  "DEVICE-123" = "Yes"
  "RAGH-BOX"   = "No"
}

$enrichment = New-SingleFieldEnrichment `
  -FieldName $field `
  -ObjectName $obj `
  -ObjectValues $values
```

### Send the enrichment

```powershell
Invoke-EnrichmentRequest -Enrichment $enrichment
```

---

## 🎯 Campaigns

```powershell
$campaign = "#Whats_for_dinner"
$userSids = @("S-1-5-21-...", "S-1-5-21-...")

Invoke-Campaign -CampaignId $campaign -Users $userSids
Invoke-Campaign -CampaignId $campaign -Users $userSids -Expires 10800
```

---

## 🔍 NQL Queries

```powershell
Invoke-NqlQuery -QueryId "#simple_query"

# With parameters
Invoke-NqlQuery -QueryId "#parametrized_query" -Parameters @{ device_name = "Laptop-01" }

# Return only data
Invoke-NqlQuery -QueryId "#simple_query" -DataOnly
```

---

## 📤 NQL Export

```powershell
Invoke-NqlExport -QueryId "#export_big_query" -OutputFolder "C:\Exports"
```

Supports compression modes: `NONE`, `GZIP`, `ZSTD`.

---

## ⚡ Workflows

### Trigger a Workflow

```powershell
Invoke-Workflow -WorkflowId "#wf_restart_service" -Devices @("uuid1","uuid2")

# Or via user identifiers:
Invoke-Workflow -WorkflowId "#wf_notify" -Users @{ sid = "S-1-5-21-..." }

# With Parameters:
$devices = @(
    @{ collectorUid = '3fa85f64-5717-4562-b3fc-2c963f66afa6' }
    @{ name        = 'LAPTOP-1234' }
)

$params = @{
    reason   = 'Standard workflow run'
    priority = 1
}

Invoke-Workflow -WorkflowId '#complex_workflow' -Devices $devices -Parameters $params
```

Support the v2 api for choosing objects by the following attributes
- Device - uid, collectorUid, name
- Users - sid, upn, uid

### List Workflows

```powershell
# List all active workflows that can be triggered via API
Invoke-ListWorkflows

# List active workflows that depend on both user and device context
Invoke-ListWorkflows -Dependency USER_AND_DEVICE

# List all scheduled workflows (active only)
Invoke-ListWorkflows -TriggerMethod SCHEDULER

# Include all workflows as well
Invoke-ListWorkflows -FetchOnlyActiveWorkflows:$false

# Get a specific workflow by NQL ID
Invoke-ListWorkflows -WorkflowId '#workflow_example'
```

---

## 👤 Author

**Trisha Gudat (NexthinkGuru)**
GitHub: https://github.com/NexthinkGuru

---

## 📄 License

MIT License – free to use, modify, and contribute.

