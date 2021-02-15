# Outlook Data File Migration Tools

These scripts are used to migrate Outlook OST and PST files into a Profile Container or Office 365 Container.

* `Get-OutookProfileDataFilePath.ps1` - exports OST and PST files mapped to a user's Outlook profile.
* `Migrate-FileToContainer.ps1` - reads a CSV file that lists usernames and paths to their OST and PST files, then creates an Office 365 Container to copy in those files. See `SampleDataFileList.csv` for sample input.
* `Migrate-OstIntoContainer.ps1` - modification of an original FSLogix script to read members of an AD group and migrate OST files into an Office 365 Container.

The migration scripts above requires the [Fslogix.Powershell.Disk](https://github.com/aaronparker/fslogix/tree/main/Modules/Fslogix.Powershell.Disk) module hosted in this repository. This is a modifed and working copy of the original [FSlogix module](https://github.com/FSLogix/Fslogix.Powershell.Disk) that has some issues.

* `Set-OutlookProfileOstPath.ps1` - Decodes the path to OST file/s in the user's Outlook profile and reencodes the path pointing to the local profile. Runs in the user session.
* `Set-OutlookProfilePstPath.ps1` - Decodes the path to PST file/s in the user's Outlook profile and reencodes the path pointing to the local profile. Runs in the user session.
