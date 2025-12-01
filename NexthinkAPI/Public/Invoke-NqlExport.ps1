function Invoke-NqlExport {
    <#
.SYNOPSIS
    Executes a Nexthink NQL export and downloads the result file.

.DESCRIPTION
    Submits an NQL query export request to Nexthink, polls the export status
    until completion or error, then downloads the resulting file to the
    specified output folder.

    This function:
      - Validates the NQL QueryId format.
      - Submits an export request with an optional compression mode.
      - Polls the export status endpoint until:
          • status = COMPLETED  → downloads the file
          • status = ERROR      → throws with the error description
      - Derives the remote file name from the returned URL.
      - Downloads the file into the given OutputFolder.
      - Warns if the resulting file is zero bytes.
      - Returns a FileInfo object for the downloaded file.

.PARAMETER QueryId
    The NQL Query Identifier to export.

    Example:
        "#my_nql_export_query"

.PARAMETER Parameters
    Optional hashtable of key/value pairs representing query parameters.
    Keys must match the parameter names defined inside the target query.

.PARAMETER Compression
    The compression mode for the exported data.

    Valid values:
        NONE  - No compression
        GZIP  - GZIP-compressed output
        ZSTD  - Zstandard-compressed output

    Default:
        NONE

.PARAMETER OutputFolder
    The directory where the exported file will be downloaded.

    Requirements:
      - Must exist and be a directory.
      - Must be writable by the current user.

    Validation:
      - Uses Test-WritableFolder -Path <OutputFolder> to ensure write access.

.INPUTS
    None. This function does not accept pipeline input.

.OUTPUTS
    [System.IO.FileInfo]

    Returns a FileInfo object representing the downloaded export file.

.EXAMPLE
    Invoke-NqlExport `
        -QueryId "#my_nql_export_query" `
        -OutputFolder "C:\Exports"

    Executes the NQL export, polls until completion, and downloads the result
    into C:\Exports. Returns the FileInfo for the downloaded file.

.EXAMPLE
    $params = @{
        fromDate = "2025-11-01"
        toDate   = "2025-11-30"
    }

    Invoke-NqlExport `
        -QueryId "#audit_events_export" `
        -Parameters $params `
        -Compression GZIP `
        -OutputFolder "C:\Exports\Logs"

    Executes a parameterized NQL export with GZIP compression and downloads
    the resulting file into C:\Exports\Logs.

.NOTES
    - The export request is submitted to the Nexthink NQL export endpoint and
      polled every 5 seconds until a terminal status is reached.
    - Nexthink-side limits (row count, execution time) still apply to the
      underlying query.
#>
    [CmdletBinding()]
    param(
        [ValidatePattern('^#[A-z0-9_]{2,255}$')]
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$QueryId,

        [parameter(Mandatory = $false)]
        [hashtable]$Parameters,

        [ValidateSet('NONE', 'GZIP', 'ZSTD', IgnoreCase = $true)]
        [parameter(Mandatory = $false)]
        [string]$Compression = 'NONE',

        [parameter(Mandatory = $true)]
        [ValidateScript({
                Test-WritableFolder -Path $_ | Out-Null
                $true
            })]
        [System.IO.DirectoryInfo]$OutputFolder
    )
    $APITYPE = 'NQL_Export'

    ## Build the body for the NQL Query execution
    $body = @{
        queryId     = $QueryId
        compression = $Compression
    }
    # add any optional dynamic parameters
    if (($null -ne $Parameters) -and ($Parameters.count -ge 1)) {
        $body.Add('parameters', $Parameters)
    }
    $bodyJson = $body | ConvertTo-Json -Depth 4

    ## Make initial API Call to get Export ID
    $exportIdResponse = Invoke-NxtApi -Type $APITYPE -Body $bodyJson -ReturnResponse

    if ($null -eq $exportIdResponse.exportId) {
        throw "No exportId returned from NQL Export request"
    }
    $exportId = $exportIdResponse.exportId
    Write-CustomLog -Message "ExportId: $exportId" -Severity "DEBUG"

    ## Now Get the Export Status and Download Link
    $APITYPE = 'NQL_Export_Status'

    while ($true) {
        Start-Sleep -Seconds 5
        $statusResponse = Invoke-NxtApi -Type $APITYPE -Query $exportId -ReturnResponse

        if ($statusResponse.status -eq 'COMPLETED') {
            $resultsFileUrl = $statusResponse.resultsFileUrl
            Write-CustomLog -Message "Results File URL: $resultsFileUrl" -Severity "DEBUG"

            $remoteFileName = [IO.Path]::GetFileName( ([uri]$resultsFileUrl).AbsolutePath )
            $outputFile = [System.IO.FileInfo](Join-Path -Path $OutputFolder -ChildPath $remoteFileName)

            break
        }
        elseif ($statusResponse.status -eq 'ERROR') {
            Write-CustomLog -Message "NQL Export returned an Error Status" -Severity "ERROR"
            throw "NQL Export Error: $($statusResponse.errorDescription)"
        }
        else {
            Write-CustomLog -Message "Export Status: $($statusResponse.status). Waiting..." -Severity "DEBUG"
        }
    }

    # Now download the file
    try {
        Write-CustomLog -Message "Downloading output to $($outputFile.Name)" -Severity "DEBUG"
        Invoke-RestMethod -Uri $resultsFileUrl -Method 'GET' -OutFile $outputFile
    }
    catch {
        Write-CustomLog -Message "Error downloading NQL Export file: $_" -Severity "ERROR"
        throw $_
    }
    # Invoke-RestMethod -Uri $resultsFileUrl -Method 'GET' | Out-File -FilePath $outputFile

    # Check the size of the output file and send a warning if it is zero bytes
    if ($outputFile.Length -eq 0) {
        Write-CustomLog -Message "Warning: NQL Export file is zero bytes: $($outputFile.FullName)" -Severity "WARNING"
    }

    return $outputFile
}