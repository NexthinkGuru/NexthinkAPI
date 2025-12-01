function Invoke-NqlExport {
    <#
    .SYNOPSIS
        Query Nexthink NQL and exports data
    .DESCRIPTION
        Triggers the execution of an NQL query, returning up to to the maximum number of results as an export file
    .INPUTS
        Query ID: An identifier for the query​. Once defined this can no longer be changed.
        Parameters: Optional hashtable of parameters used by the query.
    .OUTPUTS
        [PSCustomObject]
            queryId             string                  Identifier of the executed query
            executedQuery       string                  Final query executed with the parameters replaced
            rows                integer<int32>          Number of rows returned
            executionDateTime   DateTime                Date and time of the execution (in Nexthink Server timezone)
            data                array[PSCustomObject]   Array of PSCustomObjects containing the data rows (only if -DataOnly is not used)
    .NOTES
        Times out after 5 seconds.
    #>
    [CmdletBinding()]
    param(
        [ValidatePattern('^#[A-z0-9_]{2,255}$')]
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$QueryId,

        [parameter(Mandatory=$false)]
        [hashtable]$Parameters,

        [ValidateSet('NONE','GZIP','ZSTD', IgnoreCase=$true)]
        [parameter(Mandatory=$false)]
        [string]$Compression = 'NONE',

        [parameter(Mandatory=$true)]
        [ValidateScript({
            Test-WritableFolder -Path $_ | Out-Null
            $true
        })]
        [System.IO.DirectoryInfo]$OutputFolder
    )
    $APITYPE = 'NQL_Export'

    ## Build the body for the NQL Query execution
    $body = @{
        queryId = $QueryId
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
        } elseif ($statusResponse.status -eq 'ERROR') {
            Write-CustomLog -Message "NQL Export returned an Error Status" -Severity "ERROR"
            throw "NQL Export Error: $($statusResponse.errorDescription)"
        } else {
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