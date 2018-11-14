<#PSScriptInfo
    .VERSION 1.0
    .GUID 9c53a0e5-1cb3-4b35-90f0-372bc7665f4f
    .AUTHOR Aaron Parker, @stealthpuppy
    .COMPANYNAME stealthpuppy
    .COPYRIGHT Aaron Parker, https://stealthpuppy.com
    .TAGS FSLogix
    .LICENSEURI https://github.com/aaronparker/FSLogix/blob/master/LICENSE
    .PROJECTURI https://github.com/aaronparker/FSLogix
    .ICONURI 
    .EXTERNALMODULEDEPENDENCIES 
    .REQUIREDSCRIPTS 
    .EXTERNALSCRIPTDEPENDENCIES 
    .RELEASENOTES
    .PRIVATEDATA 
#>
<# 
    .DESCRIPTION 
        Returns strings from well known Registry keys that define a Windows application.
#> 
[CmdletBinding()]
Param (
    # Parameter help description
    [Parameter()]
    [string[]]
    $Keys = @("HKLM:\SOFTWARE\Classes\clsid", "HKLM:\SOFTWARE\Classes"),

    [Parameter()]
    [string]
    $Name = "Visio"
)

ForEach ($key in $Keys) {
    Push-Location $key
    $items = Get-ChildItem
    ForEach ($item in $items) {
        If (($item | Get-ItemProperty).'(default)' | Where-Object { $_ -like "*$Name *" }) {
            Write-Output $item.Name
        }
    }
    Pop-Location
}
