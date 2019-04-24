# FSLogix

Various scripts for use with FSLogix Apps, Containers etc.

## Stats\Get-FileStats.ps1

To report on FSLogix Containers usage, you can use `Get-FileStats.ps1` to retrieve the file size, last write time, last modifed time and file owner for Containers (.vhdx, .vhdx) files in a target file share.

## Profile-Cleanup\Remove-ProfileData.ps1

`Remove-ProfileData.ps1` is used to delete files and folders in the user profile to reduce profile size, thus keeping Profile Containers sizes to a minimum. The script reads an XML file that defines a list of files and folders to remove from the profile.
