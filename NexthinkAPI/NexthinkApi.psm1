[cmdletbinding()]
param()

Write-Verbose $PSScriptRoot

# Requires -Module Logging
# Requires -Module CredentialManager
$modules = 'Logging', 'CredentialManager'
$installed = @((Get-Module $modules -ListAvailable).Name | Select-Object -Unique)
$notInstalled = Compare-Object $modules $installed -PassThru
if ($notInstalled) { 
  $promptText = @"
  The following modules aren't currently installed:
  
      $notInstalled
  
  Would you like to install them now?
"@
  $choice = $host.UI.PromptForChoice('Missing modules', $promptText, ('&Yes', '&No'), 0)
  
  if ($choice -ne 0) { Write-Warning 'Aborted.'; exit 1 }
  
  # Install the missing modules now.
  Install-Module -Scope CurrentUser $notInstalled
}

# Load in configuration
$MAIN = ConvertFrom-Json (Get-Content "$PSScriptRoot\config\main.json" -Raw)
Set-Variable -Name MAIN -Option ReadOnly -Scope Script -Force
Export-ModuleMember -Variable MAIN

foreach ($Folder in @('Private', 'Public')) {
    $Root = Join-Path -Path $PSScriptRoot -ChildPath $Folder
    if (Test-Path -Path $Root) {
        Write-Verbose "processing folder $Root"
        $Files = Get-ChildItem -Path $Root -Filter *.ps1 -Recurse

        # dot source each file
        $Files | Where-Object { $_.name -NotLike '*.Tests.ps1' } |
        ForEach-Object { Write-Verbose $_.basename; . $PSItem.FullName }
    }
}

Export-ModuleMember -Function (Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1").BaseName
