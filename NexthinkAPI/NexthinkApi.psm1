[cmdletbinding()]
param()

# Requires -Module Logging
# Requires -Module CredentialManager
$modules = 'Logging', 'CredentialManager'
$installed = @((Get-Module $modules -ListAvailable).Name | Select-Object -Unique)
$notInstalled = Compare-Object $modules $installed -PassThru
if ($notInstalled) { # At least one module is missing.
  # Prompt for installing the missing ones.
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

