<#PSScriptInfo
    .VERSION 1.0.3
    .GUID 9c53a0e5-1cb3-4b35-90f0-372bc7665f4f
    .AUTHOR Aaron Parker, @stealthpuppy
    .COMPANYNAME stealthpuppy
    .COPYRIGHT Aaron Parker, https://stealthpuppy.com
    .TAGS FSLogix App-Masking
    .LICENSEURI https://github.com/aaronparker/FSLogix/blob/master/LICENSE
    .PROJECTURI https://github.com/aaronparker/FSLogix
    .DESCRIPTION Returns strings from well known Registry keys that define a Windows application. Used to assist in defining an FSLogix App Masking rule set.
    .ICONURI 
    .EXTERNALMODULEDEPENDENCIES 
    .REQUIREDSCRIPTS 
    .EXTERNALSCRIPTDEPENDENCIES 
    .RELEASENOTES
    - 1.0.1, First version pushed to the PowerShell Gallery, June 2019
    - 1.0.2, Fix -Key parameter in ForEach loop, Add Process block for pipeline support
    - 1.0.3, Change parameter position & pipeline support for SearchString & Key
    .PRIVATEDATA 
#>
<# 
    .SYNOPSIS
        Returns strings from well known Registry keys that define a Windows application.

    .DESCRIPTION 
        Returns strings from well known Registry keys that define a Windows application. Used to assist in defining an FSLogix App Masking rule set.

    .PARAMETER SearchString
        An array of strings to check for application names. Defaults to "Visio", "Project".

    .PARAMETER Key
        A single key or array of Registry keys to check child keys for application details. The script includes the keys typically needed for most applications.

    .EXAMPLE
        To search for Registry keys specific to Adobe Reader or Acrobat:

        C:\> .\Get-ApplicationRegistryKey.ps1 -SearchString "Adobe"

    .EXAMPLE
        To search for Registry keys specific to Visio and Project:

        C:\> .\Get-ApplicationRegistryKey.ps1 -SearchString "Visio", "Project"

    .EXAMPLE
        To search for Registry keys specific to Skype for Business:

        C:\> .\Get-ApplicationRegistryKey.ps1 -SearchString "Skype"

    .EXAMPLE
        To search for Registry keys specific to Visio and Project by passing strings to Get-ApplicationRegistryKey.ps1 via the pilpeline, use:

        C:\> "Visio", "Project" | .\Get-ApplicationRegistryKey.ps1
#>
[OutputType([System.Array])]
[CmdletBinding(SupportsShouldProcess = $False, HelpUri = "https://docs.stealthpuppy.com/docs/fslogix/appkeys")]
Param (
    [Parameter(Mandatory = $False, Position = 0, ValueFromPipeline)]
    [ValidateNotNull()]
    [System.String[]] $SearchString = @("Visio", "Project"),

    [Parameter(Mandatory = $False, Position = 1, ValueFromPipelineByPropertyName)]
    [ValidateNotNull()]
    [System.String[]] $Key = @("HKLM:\SOFTWARE\Classes\CLSID", "HKLM:\SOFTWARE\Classes", "HKLM:\SOFTWARE\Wow6432Node\Classes", `
            "HKLM:\SOFTWARE\Wow6432Node\Classes\CLSID", "HKLM:\Software\Microsoft\Office\Outlook\Addins", `
            "HKCU:\Software\Microsoft\Office\Outlook\Addins")
)
begin {
    # Get current location
    $location = Get-Location
}
process {
    try {
        # Walk through $Key
        ForEach ($path in $Key) {
            Write-Verbose -Message "Searching: $path."

            try {
                # Attempt change location to $key
                $result = Push-Location -Path $path -ErrorAction SilentlyContinue -PassThru
            }
            catch [System.Management.Automation.ItemNotFoundException] {
                Write-Warning -Message "$($MyInvocation.MyCommand): Unable to change location to $path."
                Throw $_.Exception.Message        
            }
            catch [System.Exception] {
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
    catch [System.Exception] {
        Throw $_
    }
    finally {
        # Change back to original location
        Set-Location -Path $location
    }
}
end {
}
