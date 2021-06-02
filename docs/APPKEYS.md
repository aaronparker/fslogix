# Creating FSLogix App Masking, Java Control Rules

Scripts here can be used to gather information on applications for creating rule sets for App Masking & Java Control.

`Get-ApplicationRegistryKey.ps1` returns Registry keys from well known locations that contain application information to return application keys for App Masking rules. An example use case for this would be determining specific locations for an application in a suite with shared components (e.g. Visio, Project or Skype for Business as a part of Office 365 ProPlus).

## Install the Script

There are two methods for installing the script:

1. Install from the [PowerShell Gallery](https://www.powershellgallery.com/packages/Get-ApplicationRegistryKey/). This is the preferred method as the installation can be handled directly from Windows PowerShell or PowerShell Core with the following command:

```powershell
Install-Script -Name Get-ApplicationRegistryKey
```

2. Download from the [repository](https://github.com/aaronparker/fslogix). `Get-ApplicationRegistryKey.ps1` can be downloaded directly from this repository and saved to a preferred location.

## Usage

The following example will find keys related to Microsoft Visio

```powershell
. .\Get-ApplicationRegistryKey.ps1 -SeachString "Visio"
```

The value for SearchString can be passed to `Get-ApplicationRegistryKey.ps1` via the pipeline. To search for Registry keys specific to Visio and Project by passing strings to Get-ApplicationRegistryKey.ps1 via the pipeline, use:

```powershell
C:\> "Visio", "Project" | .\Get-ApplicationRegistryKey.ps1
```

To search for Registry keys specific to Adobe Reader or Acrobat:

```powershell
C:\> .\Get-ApplicationRegistryKey.ps1 -SearchString "Adobe"
```

To search for Registry keys specific to Visio and Project:

```powershell
C:\> .\Get-ApplicationRegistryKey.ps1 -SearchString "Visio", "Project"
```

To search for Registry keys specific to Skype for Business:

```powershell
C:\> .\Get-ApplicationRegistryKey.ps1 -SearchString "Skype"
```

A list of Registry keys can be passed to `Get-ApplicationRegistryKey.ps1` on the pipeline from an object with a `Key` property. For example, consider an object named `$List` that has a set of Registry paths in a property named `Key`:

```powershell
C:\> $List

Title Key
----- ---
Path  HKLM:\SOFTWARE\Classes\CLSID
Path  HKLM:\SOFTWARE\Classes
```

This object can be passed to `Get-ApplicationRegistryKey.ps1` on the pipeline as per the following example:

```powershell
$List | . "\\Mac\Home\projects\FSLogix\Rules\Get-ApplicationRegistryKey.ps1" -Verbose -SearchString "Visio"
```

In each case, the script will output a list of keys, similar to the list below, that can then be validated and used in an App Masking ruleset:

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
