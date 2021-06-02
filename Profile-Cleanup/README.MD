# Profile Cleanup

## WARNING

Caveat Emptor - this script will **DELETE** target files and folders. Be certain that the targets listed in the XML are OK to be removed. Test and test again before putting the script into production.

## Profile Capacity Management

A full discussion on managing Profile Container size can be found in this article: [A Practical Guide to FSLogix Containers Capacity Planning and Maintenance](https://stealthpuppy.com/fslogix-containers-capacity/).

## About Remove-ProfileData.ps1

`Remove-ProfileData.ps1` is used to delete files and folders in the user profile to reduce profile size, thus keeping Profile Containers sizes to a minimum. The script runs within the user session and reads an XML file that defines a list of files and folders to remove from the profile. Actions on a target path can be:

* Prune - the XML can include a number that defines the age in days for last write that the file must be older than to be deleted. Essentially reducing the size of the folder.
* Delete - the target path will be deleted. Where the administrator may want to remove a target path, the Delete action will delete the entire folder.
* Trim - where the target path contains sub-folders, this action will remove all sub-folders except for the newest folder.

Supports `-WhatIf` and `-Verbose` output and returns a list of files removed from the profile. Add `-Verbose` will output the total size of files removed from the user profile and processing time at the end of the script. All targets (files / folders) that are deleted, will be logged to a file.

Deleting files from the profile can potentially result in data loss, so testing is advised and the use of `-Confirm:$false` is required for the script perform a delete.

### Usage

```powershell
.\Remove-ProfileData.ps1 -Targets .\targets.xml
```

![Output from Remove-ProfileData.png](assets/images/ProfileDataOutput.png "Output from Remove-ProfileData.png")

## About Remove-ContainerData.ps1

`Remove-ContainerData` is used to delete files and folders in a user's FSLogix Profile Container by mounting the Container and pruning files, thus keeping the Container size to a minimum. The script reads an XML file that defines a list of files and folders to remove from the Container. Actions on a target path can be:

* Prune - the XML can include a number that defines the age in days for last write that the file must be older than to be deleted. Essentially reducing the size of the folder.
* Delete - the target path will be deleted. Where the administrator may want to remove a target path, the Delete action will delete the entire folder.
* Trim - where the target path contains sub-folders, this action will remove all sub-folders except for the newest folder.

Supports `-WhatIf` and `-Verbose` output and returns a list of files removed from the profile. Add `-Verbose` will output the total size of files removed from the user profile and processing time at the end of the script. All targets (files / folders) that are deleted, will be logged to a file.

Deleting files from the Container can potentially result in data loss, so testing is advised and the use of `-Confirm:$false` is required for the script perform a delete.

This script depends on the following PowerShell modules:

* `ActiveDirectory` - Installed as a feature in Windows Server or via [RSAT](https://support.microsoft.com/en-us/help/2693643/remote-server-administration-tools-rsat-for-windows-operating-systems)
* `Hyper-V` - Installed as a feature in Windows Server or via [RSAT](https://support.microsoft.com/en-us/help/2693643/remote-server-administration-tools-rsat-for-windows-operating-systems)
* `Fslogix.Powershell.Disk` - this module is found here: [https://github.com/aaronparker/fslogix/tree/main/Modules/Fslogix.Powershell.Disk](https://github.com/aaronparker/fslogix/tree/main/Modules/Fslogix.Powershell.Disk)

### Usage

```powershell
.\Remove-ContainerData.ps1 -Path \\server\FSLogixContainer -Targets .\targets.xml
```
