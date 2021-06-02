# Get-FileStats.ps1

To report on FSLogix Containers usage, you can use `Get-FileStats.ps1` to retrieve the file size, last write time, last modifed time and file owner for Containers (.vhdx, .vhdx) files in a target file share.

Example - this will retrieve details for container files in a target share and output the results to a Gridview window:

```powershell
.\Get-FileStats.ps1 -Path \\server\share\folder -Include *.vhd, *.vhdx | Out-GridView
```

Outputing a view similar to this:

![File stats for FSLogix Containers](assets/images/FileStatsGridView.PNG "File stats for FSLogix Containers")
