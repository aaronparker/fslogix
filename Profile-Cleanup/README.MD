# Profile Cleanup

`Remove-ProfileData.ps1` is used to delete files and folders in the user profile to reduce profile size, thus keeping Profile Containers sizes to a minimum. The script reads an XML file that defines a list of files and folders to remove from the profile. Actions on a target path can be:

* Prune - the XML can include a number that defines the age in days for last write that the file must be older than to be deleted. Essentially reducing the size of the folder.
* Delete - the target path will be deleted. Where the administrator may want to remove a target path, the Delete action will delete the entire folder.
* Trim - where the target path contains sub-folders, this action will remove all sub-folders except for the newest folder.

Supports `-WhatIf` and `-Verbose` output and returns a list of files removed from the profile. Add `-Verbose` will output the total size of files removed from the user profile and processing time at the end of the script. All targets (files / folders) that are deleted, will be logged to a file.

Deleting files from the profile can potentially result in data loss, so testing is advised and the use of `-Confirm:$false` is required for the script perform a delete.

WARNING: This script will DELETE target files and folders. Be certain that the targets listed in the XML are OK to be removed. Test before putting the script into production.

![Output from Remove-ProfileData.png](https://raw.githubusercontent.com/aaronparker/FSLogix/master/img/ProfileDataOutput.png "Output from Remove-ProfileData.png")
