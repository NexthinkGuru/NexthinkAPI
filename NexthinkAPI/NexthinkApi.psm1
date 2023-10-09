[cmdletbinding()]
param()

Write-Verbose $PSScriptRoot

$moduleName = 'NexthinkAPI'
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

# # Check for updates to the module 'MyModule'
# $currentVersion = Get-Module -Name $moduleName | Select-Object Version
# $latestVersion = Find-Module -Name $moduleName -Repository PSGallery| Select-Object Version

# # Compare the two versions
# if ($currentVersion.Version -lt $latestVersion.Version) {
#     # The module needs to be updated
#     Write-Host -NoNewline "The module "
#     Write-Host -NoNewline "'$($moduleName)'" -ForegroundColor Blue  
#     Write-Host -NoNewline " is out of date! The latest version is "
#     Write-Host -NoNewline "'$($latestVersion.Version)'." -ForegroundColor Green
#     Write-Host "Please update before running again to avoid any issues."
#     Write-Host -NoNewline "   Example: "
#     Write-Host "Update-Module $($moduleName) -Scope CurrentUser" -ForegroundColor Red
# }


# Load in configuration
$MAIN = ConvertFrom-Json (Get-Content "$PSScriptRoot\config\main.json" -Raw)
Set-Variable -Name MAIN -Option ReadOnly -Scope Script -Force
Export-ModuleMember -Variable MAIN

foreach ($folder in @('Private', 'Public')) {
    $root = Join-Path -Path $PSScriptRoot -ChildPath $folder
    if (Test-Path -Path $root) {
        Write-Verbose "processing folder $root"
        $files = Get-ChildItem -Path $root -Filter *.ps1 -Recurse

        # dot source each file
        $files | Where-Object { $_.name -NotLike '*.Tests.ps1' } |
        ForEach-Object { Write-Verbose $_.basename; . $PSItem.FullName }
    }
}

Export-ModuleMember -Function (Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1").BaseName
