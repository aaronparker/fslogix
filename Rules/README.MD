# Creating FSLogix App Masking, Java Control Rules

Scripts here can be used to gather information on applications for creating rule sets for App Masking & Java Control.

## Get-ApplicationRegistryKey.ps1

Returns Registry keys from well known locations that contain application information to return application keys for App Masking rules. An example use case for this would be determining specific locations for an application in a suite with shared components (e.g. Visio as a part of Office 365 ProPlus).

The following example will find keys related to Microsoft Visio

```powershell
. .\Get-ApplicationRegistryKey.ps1 -SeachString "Visio"
```

The script will output a list of keys, similar to the list below, that can then be validated and used in an App Masking ruleset for Visio:

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
