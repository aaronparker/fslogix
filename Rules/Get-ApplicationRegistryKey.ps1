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

    .PARAMETER Key
        A single key or array of Registry keys to check child keys for application details. The script includes the keys typically needed for most applications.

    .PARAMETER SearchString
        An array of strings to check for application names

    .EXAMPLE
        To search for Registry keys specific to Adobe Reader or Acrobat:

        C:\> . "\\Mac\Home\Projects\FSLogix\Rules\Get-ApplicationRegistryKey.ps1" -SearchString "Adobe"

    .EXAMPLE
        To search for Registry keys specific to Visio and Project:

        C:\> . "\\Mac\Home\Projects\FSLogix\Rules\Get-ApplicationRegistryKey.ps1" -SearchString "Visio", "Project"
#>
[OutputType([System.Array])]
[CmdletBinding(SupportsShouldProcess = $False, HelpUri = "https://github.com/aaronparker/FSLogix/blob/master/Rules/README.MD")]
Param (
    [Parameter(Mandatory = $False, Position = 0, ValueFromPipeline)]
    [ValidateNotNull()]
    [System.String[]] $Key = @("HKLM:\SOFTWARE\Classes\CLSID", "HKLM:\SOFTWARE\Classes", "HKLM:\SOFTWARE\Wow6432Node\Classes", `
            "HKLM:\SOFTWARE\Wow6432Node\Classes\CLSID", "HKLM:\Software\Microsoft\Office\Outlook\Addins", `
            "HKCU:\Software\Microsoft\Office\Outlook\Addins"),

    [Parameter(Mandatory = $False, Position = 1, ValueFromPipeline)]
    [ValidateNotNull()]
    [System.String[]] $SearchString = @("Visio", "Project")
)

# Get current location
$location = Get-Location

try {
    # Walk through $Keys
    ForEach ($key in $Keys) {
        Write-Verbose -Message "Searching: $key."

        try {
            # Attempt change location to $key
            $result = Push-Location -Path $key -ErrorAction SilentlyContinue -PassThru
        }
        catch [System.Management.Automation.ItemNotFoundException] {
            Write-Warning -Message "$($MyInvocation.MyCommand): Unable to change location to $key."
            Throw $_.Exception.Message        
        }
        catch [System.SystemException] {
            Throw $_
        }
        # If successfully changed to the target key, get child keys and match against data in the default values
        If ($result.Length -gt 0) {
            $regItems = Get-ChildItem
            ForEach ($item in $regItems) {
                ForEach ($string in $SearchString) {
                    If (($item | Get-ItemProperty).'(default)' | Where-Object { $_ -like "*$string*" }) {
                        Write-Verbose -Message "Found '$(($item | Get-ItemProperty).'(default)')'."
                        Write-Output -InputObject $item.Name
                    }
                }
            }
        }
    }
}
catch [System.SystemException] {
    Throw $_
}
finally {
    # Change back to original location
    Set-Location -Path $location
}
