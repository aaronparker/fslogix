# Creating FSLogix App Masking rule sets

Scripts here can be used to gather information on applications for creating rule sets for App Masking & Java Control.

## New-MicrosoftOfficeRuleset.ps1

This script will create an FSLogix App Masking rule set for Office applications. The script requires the [`FSLogix.PowerShell.Rules`](https://www.powershellgallery.com/packages/FSLogix.PowerShell.Rules/) PowerShell module. Install this module first with:

```powershell
Install-Module -Name "FSLogix.PowerShell.Rules" 
```

`New-MicrosoftOfficeRuleset.ps1` has been tested with the Microsoft 365 Apps / Office 365 ProPlus and should also work with Office 2019. It may work for Office 2013 / 2016. Download `New-MicrosoftOfficeRuleset.ps1` from here: [https://github.com/aaronparker/fslogix/tree/main/Rules](https://github.com/aaronparker/fslogix/tree/main/Rules)

### Usage

`New-MicrosoftOfficeRuleset.ps1` should be used to create an App Masking rule set for one application at a time. It will output a rule set files in the default `Documents\FSLogix Rulesets`. Adding the `-Verbose` parameter is recommended to print registry and folder search information to the screen during execution.

For example, to create an FSLogix App Masking rule set for Microsoft Visio:

```powershell
.\New-MicrosoftOfficeRuleset.ps1 -SearchString "Visio"
```

To create an FSLogix App Masking rule set for Microsoft Project use the following syntax. Note that the word `Project` is a generic word and therefore the generated rule set file may also include Registry keys and folders that are not specific to Microsoft Project. Manually edit the rule set file once the script completes and remove any items that do not relate directly to Project.

```powershell
.\New-MicrosoftOfficeRuleset.ps1 -SearchString "Project", "WinProj"
```

To create an FSLogix App Masking rule set for Microsoft Access. Note that the word `Access` is a generic word and therefore the generated rule set file may also include Registry keys and folders that are not specific to Microsoft Access. Manually edit the rule set file once the script completes and remove any items that do not relate directly to Access.

```powershell
.\New-MicrosoftOfficeRuleset.ps1 -SearchString "Access"
```

To create an FSLogix App Masking rule set for Microsoft Publisher. Note that the word `Publisher` is a generic word and therefore the generated rule set file may also include Registry keys and folders that are not specific to Microsoft Publisher. Manually edit the rule set file once the script completes and remove any items that do not relate directly to Publisher.

```powershell
.\New-MicrosoftOfficeRuleset.ps1 -SearchString "Publisher"
```

## Get-ApplicationRegistryKey.ps1

Returns Registry keys from well known locations that contain application information to return application keys for App Masking rules. An example use case for this would be determining specific locations for an application in a suite with shared components (e.g. Visio as a part of Office 365 ProPlus).

### Installation

`Get-ApplicationRegistryKey.ps1` can be installed from the [PowerShell Gallery](https://www.powershellgallery.com/packages/Get-ApplicationRegistryKey/) with the following command:

```powershell
Install-Script -Name Get-ApplicationRegistryKey
```

If you encounter issues installing the script, ensure that [PowerShellGet](https://docs.microsoft.com/en-us/powershell/scripting/gallery/installing-psget) is up to date. On Windows 10 and Windows Server 2016 / 2019 the following commands can be used to update PowerShellGet.

```powershell
Install-Module -Name PowerShellGet -Force
Update-Module -Name PowerShellGet
```

### Usage

The following example will find keys related to Microsoft Visio

```powershell
.\Get-ApplicationRegistryKey.ps1 -SearchString "Visio"
```

The script will output a list of keys, similar to the list below, that can then be validated and used in an App Masking rule set for Visio:

```text
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Icad.ViewerDrawing
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\ms-visio
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\ShapewareVISIO10
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\ShapewareVISIO20
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Visio.Application
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Visio.Application.11
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Visio.Application.3
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Visio.Application.4
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Visio.Application.5
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Visio.Application.6
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Visio.CustomUI.11
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Visio.Drawing
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Visio.Drawing.11
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Visio.Drawing.15
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Visio.Drawing.3
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Visio.Drawing.4
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Visio.Drawing.5
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Visio.Drawing.6
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Visio.DrawingMacroEnabled
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Visio.DrawingMacroEnabled.15
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Visio.ExtendedData
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Visio.InvisibleApp
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Visio.InvisibleApp.11
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Visio.Stencil.11
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Visio.Stencil.15
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Visio.StencilMacroEnabled.15
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Visio.Template.11
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Visio.Template.15
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Visio.TemplateMacroEnabled.15
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Visio.TemplatePackage.16
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Visio.WebDrawing.14
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Visio.Workspace.11
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\VisioBridger.Loader
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\VisioSGFS.Engine
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\VisioSGProv.Provider
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\VisioViewer.Viewer
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\VisioViewer.Viewer.1
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\VisioViewerDWGDisplay.VisioViewerDWGDisplay
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\VisioViewerDWGDisplay.VisioViewerDWGDisplay.1
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\VisioViewerDWGDisplayCreator.VisioViewerDWGDisplayCreator
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\VisioViewerDWGDisplayCreator.VisioViewerDWGDisplayCreator.1
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\VisOcx.DrawingControl
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\VisOcx.DrawingControl.1
```
