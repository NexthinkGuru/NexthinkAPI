function Install-NexthinkApiPrereqs {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [string[]]$Modules = @('Logging', 'CredentialManager'),
        [switch]$Force
    )

    Write-Host "Installing prerequisites for NexthinkAPI module..." -ForegroundColor Cyan
    Write-Host "Checking required modules: $($Modules -join ', ')"

    try {
        $null = Find-Module -Name $Modules[0] -Repository PSGallery -ErrorAction Stop
    }
    catch {
        throw "Unable to reach PSGallery. Prerequisites cannot be installed. Details: $($_.Exception.Message)"
    }

    $available = (Get-Module -ListAvailable -Name $Modules).Name | Select-Object -Unique
    $missing   = $Modules | Where-Object { $_ -notin $available }

    if (-not $missing) {
        Write-Host "All prerequisites already installed." -ForegroundColor Green
        return
    }

    Write-Host "Missing modules: $($missing -join ', ')" -ForegroundColor Yellow

    if (-not $Force) {
        $caption = 'Install prerequisites'
        $message = "Install missing modules from PSGallery?"
        $options = '&Yes', '&No'
        $choice  = $Host.UI.PromptForChoice($caption, $message, $options, 0)

        if ($choice -ne 0) {
            throw "Aborted prerequisite installation."
        }
    }

    foreach ($m in $missing) {
        if ($PSCmdlet.ShouldProcess($m, "Install-Module -Scope CurrentUser")) {
            Install-Module -Name $m -Scope CurrentUser -Force:$Force -ErrorAction Stop
        }
    }

    Write-Host "Prerequisite installation complete." -ForegroundColor Green
}
