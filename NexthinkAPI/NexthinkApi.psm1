using namespace System.Management.Automation
class ValidateWritableFolderAttribute : ValidateArgumentsAttribute {

    hidden [bool] TestWritable([string] $path, [ref] $errorMsg) {

        # Resolve the path
        try {
            $resolved = Convert-Path -LiteralPath $path -ErrorAction Stop
        }
        catch {
            $errorMsg.Value = "Path '$path' does not exist."
            return $false
        }

        # Must be a directory
        if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
            $errorMsg.Value = "Path '$path' is not a directory."
            return $false
        }

        # Try writing a temp file
        $tmpFile = Join-Path $resolved ".writetest.tmp"

        try {
            New-Item -Path $tmpFile -ItemType File -Force -ErrorAction Stop | Out-Null
            Remove-Item -LiteralPath $tmpFile -Force -ErrorAction Stop
        }
        catch {
            $errorMsg.Value = "Folder '$path' is not writable. Details: $($_.Exception.Message)"
            return $false
        }

        return $true
    }

    [void] Validate([object] $arguments, [EngineIntrinsics] $engineIntrinsics) {

        if ($null -eq $arguments) {
            throw [ValidationMetadataException]::new("Output folder cannot be null.")
        }

        if (-not ($arguments -is [string])) {
            throw [ValidationMetadataException]::new("Output folder must be a string path.")
        }

        $msg = $null
        if (-not $this.TestWritable([string]$arguments, [ref]$msg)) {
            throw [ValidationMetadataException]::new($msg)
        }
    }
}

Write-Verbose "Loading module from $PSScriptRoot"

# Required dependency modules
$requiredModules = 'Logging', 'CredentialManager'

$available = Get-Module -ListAvailable -Name $requiredModules
$availableNames = $available.Name | Select-Object -Unique

$missing = $requiredModules | Where-Object { $_ -notin $availableNames }

if ($missing) {

    $missingList = $missing -join ', '

    $msg = @"
The following required modules are missing:
    $missingList

Run the following command to install prerequisites:

    Install-NexthinkApiPrereqs

Then import the NexthinkAPI module again.
"@

    Write-Warning $msg
    throw "Missing prerequisites: $missingList"
}

# Optional update check for this module
# Controlled by env var: NEXTHINKAPI_SKIP_UPDATECHECK=1 to disable
$moduleName = 'NexthinkAPI'

if ($env:NEXTHINKAPI_SKIP_UPDATECHECK -ne '1') {
    try {
        $currentModule = Get-Module -ListAvailable -Name $moduleName | Sort-Object Version -Descending | Select-Object -First 1
        $latestModule  = Find-Module -Name $moduleName -Repository PSGallery -ErrorAction Stop

        if ($currentModule -and $currentModule.Version -lt $latestModule.Version) {
            Write-Host -NoNewline "The module "
            Write-Host -NoNewline "'$moduleName'" -ForegroundColor Blue
            Write-Host -NoNewline " is out of date! The latest version is "
            Write-Host -NoNewline "'$($latestModule.Version)'." -ForegroundColor Green
            Write-Host " Please update before running again to avoid any issues."
            Write-Host -NoNewline "   Example: "
            Write-Host "Update-Module $moduleName -Scope CurrentUser" -ForegroundColor Red
        }
    }
    catch {
        # Don't break module load if PSGallery is unreachable
        Write-Verbose "Skipping update check for $moduleName. Reason: $($_.Exception.Message)"
    }
}

# Load MAIN config
$mainConfigPath = Join-Path -Path $PSScriptRoot -ChildPath 'config\main.json'
write-Verbose "Loading main configuration from $mainConfigPath"
if (-not (Test-Path -LiteralPath $mainConfigPath)) {
    $msg = "Unable to locate main configuration file: $mainConfigPath"
    Write-Error $msg
    throw $msg
}

try {
    $script:MAIN = Get-Content -LiteralPath $mainConfigPath -Raw | ConvertFrom-Json
    Set-Variable -Name MAIN -Scope Script -Option ReadOnly -Force -Value $script:MAIN
}
catch {
    $msg = "Failed to load or parse $mainConfigPath. Details: $($_.Exception.Message)"
    Write-Error $msg
    throw $msg
}

# Dot-source Private and Public functions
foreach ($folder in @('Private', 'Public')) {
    $root = Join-Path -Path $PSScriptRoot -ChildPath $folder

    if (Test-Path -LiteralPath $root) {
        Write-Verbose "Processing folder $root"

        Get-ChildItem -Path $root -Filter *.ps1 -Recurse |
            Where-Object { $_.Name -notlike '*.Tests.ps1' } |
            ForEach-Object {
                Write-Verbose "Dot-sourcing $($_.FullName)"
                . $_.FullName
            }
    }
}


# Export public functions + MAIN variable
$publicFunctions = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter *.ps1 -ErrorAction SilentlyContinue |
                   Select-Object -ExpandProperty BaseName

if ($publicFunctions) {
    Export-ModuleMember -Function $publicFunctions -Variable MAIN
}
else {
    Export-ModuleMember -Variable MAIN
}
