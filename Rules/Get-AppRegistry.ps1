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
    $Keys = @("HKLM:\SOFTWARE\Classes\CLSID", "HKLM:\SOFTWARE\Classes", "HKLM:\SOFTWARE\Wow6432Node\Classes", `
            "HKLM:\SOFTWARE\Wow6432Node\Classes\CLSID", "HKLM:\Software\Microsoft\Office\Outlook\Addins", `
            "HKCU:\Software\Microsoft\Office\Outlook\Addins"),

    [Parameter()]
    [string[]]
    $Name = "Visio"
)

# Get current location
$location = Get-Location

# Walk through $Keys
ForEach ($key in $Keys) {
    Write-Verbose -Message "Checking $key."

    # Change location to $key
    try {
        Push-Location $key -ErrorAction SilentlyContinue -ErrorVariable CdError
    }
    catch {
        
        # If $key is not a valid location, fail somewhat gracefully
        Write-Error "Unable to change location to $key."
        Break
    }
    finally {

        # Get child keys and match against data in the default values
        $items = Get-ChildItem
        ForEach ($item in $items) {
            ForEach ($string in $Name) {
                If (($item | Get-ItemProperty).'(default)' | Where-Object { $_ -like "*$string *" }) {
                    Write-Verbose "Found '$(($item | Get-ItemProperty).'(default)')'."
                    Write-Output $item.Name
                }
            }
        }
    }
}

# Change back to original location
Set-Location $location
