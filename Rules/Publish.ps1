<#
    Publish Get-ApplicationRegistryKey.ps1 to the PowerShell Gallery
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true)]
    [System.String] $ApiKey
)

#region NuGet
Install-PackageProvider -Name NuGet -Force
Install-Module -Name PowerShellGet -Force
If (Get-PSRepository -Name PSGallery | Where-Object { $_.InstallationPolicy -ne "Trusted" }) {
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}
#region

#region Setup
If (Test-Path 'env:APPVEYOR_BUILD_FOLDER') {
    # AppVeyor Testing
    $projectRoot = $env:APPVEYOR_BUILD_FOLDER
    Write-Host -ForegroundColor Cyan "Project root is: $projectRoot"
}
Else {
    # Local Testing 
    $projectRoot = "$(Split-Path -Parent -Path $MyInvocation.MyCommand.Definition)"
    Write-Host -ForegroundColor Cyan "Project root is: $projectRoot"
}

# Get variables
$script = Get-ChildItem "$projectRoot" -Recurse -Include "Get-ApplicationRegistryKey.ps1"
Write-Host "Script location is: $script."
#endregion

# Publish the script
$PS = @{
    Path        = $script
    NuGetApiKey = $ApiKey
    Repository  = "PSGallery"
    ErrorAction = 'Stop'
}
Publish-Script @PS -Verbose
