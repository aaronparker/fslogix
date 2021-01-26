#Requires -RunAsAdministrator
<#
    .SYNOPSIS    
    Creates FSLogix App Masking rulesets for Microsoft Office applications.
    Outputs files in "Documents\FSLogix Rule Sets". Rule sets will require manual validation.

    .EXAMPLE
    To create an FSLogix App Masking ruleset for Visio:

    C:\> .\New-MicrosoftOfficeRuleset.ps1 -SearchString "Visio"

    .EXAMPLE
    To create an FSLogix App Masking ruleset for Project:

    C:\> .\New-MicrosoftOfficeRuleset.ps1 -SearchString "Project", "WinProj"

    .EXAMPLE
    To create an FSLogix App Masking ruleset for Access:

    C:\> .\New-MicrosoftOfficeRuleset.ps1 -SearchString "Access"
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $True, Position = 0)]
    [ValidateNotNull()]
    [System.String[]] $SearchString,

    [Parameter(Mandatory = $False, Position = 2)]
    [ValidateNotNull()]
    [System.String[]] $Folders = @("$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
        "$env:ProgramFiles\Microsoft Office\root\Office16", "$env:ProgramFiles\Microsoft Office\root\Integration",
        "$env:ProgramFiles\Microsoft Office\root\rsod", "$env:ProgramFiles\Microsoft Office\root\Office16\1033",
        "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16", "${env:ProgramFiles(x86)}\Microsoft Office\root\Integration",
        "${env:ProgramFiles(x86)}\Microsoft Office\root\rsod", "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16\1033")
)

#region Functions
Function Convert-Path {
    <#
        .SYNOPSIS
        Replaces paths with environment variables
    #>
    Param (
        [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True)]
        [System.String] $Path
    )
    Switch ($Path) {
        { $_ -match "HKEY_LOCAL_MACHINE" } { $Path = $Path -replace "HKEY_LOCAL_MACHINE", "HKLM" }
        { $_ -match "C:\\Program Files \(x86\)" } { $Path = $Path -replace "C:\\Program Files \(x86\)", "%ProgramFilesFolder32%" }
        { $_ -match "C:\\Program Files" } { $Path = $Path -replace "C:\\Program Files", "%ProgramFilesFolder64%" }
        { $_ -match "C:\\ProgramData\\Microsoft\\Windows\\Start Menu" } { $Path = $Path -replace "C:\\ProgramData\\Microsoft\\Windows\\Start Menu", "%CommonStartMenuFolder%" }
        { $_ -match "C:\\ProgramData" } { $Path = $Path -replace "C:\\ProgramData", "%CommonAppDataFolder%" }
    }
    Write-Output -InputObject $Path
}
#endregion

# Install required scripts and modules from the PowerShell Gallery
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.208
If (Get-PSRepository -Name PSGallery | Where-Object { $_.InstallationPolicy -ne "Trusted" }) {
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}
Install-Module -Name FSLogix.Powershell.Rules -Force
Install-Script -Name Get-ApplicationRegistryKey -Force

# Set up the ruleset file
$Documents = [Environment]::GetFolderPath('MyDocuments')
$RulesetsFolder = "$Documents\FSLogix Rule Sets"
$Ruleset = "$RulesetsFolder\Microsoft$($SearchString[0]).fxr"
New-Item -Path $RulesetsFolder -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

$Keys = @(); $Files = @(); $Dirs = @()
ForEach ($string in $SearchString) {
    # Grab registry keys related to this application
    $Keys += Get-ApplicationRegistryKey.ps1 -SearchString $string

    # Grab files related to this application
    ForEach ($folder in $Folders) {
        $Files += Get-ChildItem -Path $folder -Filter "$string*" -File -ErrorAction SilentlyContinue
    }

    # Grab folders related to this application
    ForEach ($folder in $Folders) {
        $Dirs = Get-ChildItem -Path $folder -Filter "$string*" -Directory -ErrorAction SilentlyContinue
    }
}

# Write paths to the App Masking ruleset file
ForEach ($key in $Keys) {
    Add-FslRule -Path $Ruleset -FullName (Convert-Path -Path $key) -HidingType FolderOrKey -Comment "Added by $($MyInvocation.MyCommand)."
}
ForEach ($file in $Files) {
    Add-FslRule -Path $Ruleset -FullName (Convert-Path -Path $file.FullName) -HidingType FileOrValue -Comment "Added by $($MyInvocation.MyCommand)."
}
ForEach ($dir in $Dirs) {
    Add-FslRule -Path $Ruleset -FullName (Convert-Path -Path $dir.FullName) -HidingType FolderOrKey -Comment "Added by $($MyInvocation.MyCommand)."
}

Write-Host -ForegroundColor Cyan "Ruleset file: $Ruleset."
