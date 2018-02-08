# FSLogix
Various scripts for use with FSLogix Apps, Containers etc.

## Get-FileAge.ps1
To report on FSLogix Containers usage, you can use Get-FileAge.ps1 to retrieve the file last write time, last modifed time and file owner for Containers (.vhdx, .vhdx) files in a target file share.

Example - this will retrieve details for container files in a target share and output the results to a Gridview window:

	.\Get-FileAge.ps1 -Path \\server\share\folder -Include *.vhd, *.vhdx | Out-GridView
