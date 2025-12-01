function Test-IsValidNqlId {
    param([string]$QueryId)

    if ($QueryId -match '^#?[A-Za-z0-9_-]{2,255}$') {
        return $true
    }
    return $false
}

function Test-WritableFolder {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [Alias('FullName')]
        [ValidateNotNullOrEmpty()]
        [System.IO.DirectoryInfo]$Path
    )

    # Resolve PSDrive/relative paths to a full filesystem path
    $resolvedPath = $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path.FullName)

    # Ensure it's a directory
    if (-not (Test-Path -LiteralPath $resolvedPath -PathType Container)) {
        throw "Path '$resolvedPath' is not a directory."
    }

    # Try writing a temp file to verify write access
    $tmpFile = Join-Path $resolvedPath ".writetest.tmp"

    try {
        New-Item -Path $tmpFile -ItemType File -Force -ErrorAction Stop | Out-Null
        Remove-Item -LiteralPath $tmpFile -Force -ErrorAction Stop
    }
    catch {
        throw "Folder '$resolvedPath' is not writable. Details: $($_.Exception.Message)"
    }

    # Return a DirectoryInfo for callers that want to use it
    return [System.IO.DirectoryInfo]$resolvedPath
}

function Test-IsValidSID {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [string]$ObjectSID
    )

    process {
        try {
            # If this succeeds, the SID is syntactically valid
            $null = [System.Security.Principal.SecurityIdentifier]::new($ObjectSID)
            return $true
        }
        catch {
            return $false
        }
    }
}
