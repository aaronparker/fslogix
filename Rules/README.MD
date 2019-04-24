# Creating FSLogix App Masking, Java Control Rules

Scripts here can be used to gather information on applications for creating rule sets for App Masking & Java Control.

## Get-AppRegistry.ps1

Returns Registry keys from well known locations that contain application information to return application keys for App Masking rules. An example use case for this would be determining specific locations for an application in a suite with shared components (e.g. Visio as a part of Office 365 ProPlus).

The following example will find keys related to Microsoft Visio

```powershell
Get-AppRegistry.ps1 -Name "Visio"
``