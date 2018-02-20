# Profile Cleanup

Remove-ProfileData.ps1 is used to delete files and folders in the user profile to reduce profile size, thus keeping Profile Containers sizes to a minimum. The script reads an XML file that defines a list of files and folders to remove from the profile. The XML can include a number that defines the age in days for last write that the file must be older than to be deleted.

Supports -WhatIf and -Verbose output and returns a list of files removed from the profile. Add -Verbose will output the total size of files removed from the user profile and processing time at the end of the script.

Deleting files from the profile can potentially result in data loss, so testing is advised and the use of -Confirm:$false is required for the script perform a delete.

WARNING: This script in in early stages of development and will DELETE target files and folders.

![Output from Remove-ProfileData.png](https://raw.githubusercontent.com/aaronparker/FSLogix/master/img/ProfileDataOutput.png "Output from Remove-ProfileData.png")