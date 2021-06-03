#Requires -Version 2
#Requires -PSEdition Desktop
<#
    .SYNOPSIS
        Removes files and folders in the user profile to reduce profile size.
        Constrained Language Mode version.

    .DESCRIPTION
        Reads a list of files and folders from an XML file to delete data based on age.
        The script reads an XML file that defines a list of files and folders to remove to reduce profile size.
        Supports -WhatIf and -Verbose output and returns a list of files removed from the profile.
        Run within the user session to prune the local profile.

    .PARAMETER Targets
        Path to an XML file that defines the profile paths to prune and delete.

    .PARAMETER LogPath
        Path to a directory for storing log files that log all files that are removed. Defaults to %LocalAppData%.

    .PARAMETER Override
        Override the Days value listed for each Path with action Prune, in the XML file resulting in the forced removal of all files in the path.

    .PARAMETER KeepLog
        A integer value between 0 and 256 for the number of logs to keep. Defaults to 30. The oldest log files will be removed.

    .EXAMPLE
        C:\> .\Remove-ProfileData.ps1 -Targets .\targets.xml -WhatIf

        Description:
        Reads targets.xml that defines a list of files and folders to delete from the user profile.
        Reports on the files/folders to delete without deleting them. A log file of deleted files and folders will be kept in %LocalAppData%.

    .EXAMPLE
        C:\> .\Remove-ProfileData.ps1 -Targets .\targets.xml -LogPath \\server\share\logs -Confirm:$False -Verbose

        Description:
        Reads targets.xml that defines a list of files and folders to delete from the user profile.
        Deletes the targets and reports on the total size of files removed. A log file of deleted files and folders will be kept in \\server\share\logs.

    .INPUTS
        XML file that defines target files and folders to remove.

    .NOTES
        Windows profiles can be cleaned up to reduce profile size and bloat.
        Use with traditional profile solutions to clean up profiles or with Container-based solution to keep Container sizes to minimum.
#>
[CmdletBinding(HelpUri = 'https://stealthpuppy.com/fslogix/profilecleanup/')]
[OutputType([System.String])]
Param (
    [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript( { If (Test-Path $_ -PathType 'Leaf') { $True } Else { Throw "Cannot find targets file: $_." } })]
    [Alias("Path", "Xml")]
    [System.String] $Targets,

    [Parameter(Mandatory = $False, Position = 1)]
    [ValidateScript( { If (Test-Path -Path $_ -PathType 'Container') { $True } Else { Throw "Cannot find log file directory: $_." } })]
    [System.String] $LogPath = (Resolve-Path -Path $env:LocalAppData),

    [Parameter(Mandatory = $False)]
    [System.Management.Automation.SwitchParameter] $Override,

    [Parameter(Mandatory = $False)]
    [ValidateRange(1, 256)]
    [System.Int32] $KeepLog = 30
)

#region Functions
Function ConvertTo-Path {
    <#
          .SYNOPSIS
            Replaces environment variables in strings with actual path
        #>
    Param (
        [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True)]
        [System.String] $Path
    )
    Switch ($Path) {
        { $_ -match "%USERPROFILE%" } { $Path = $Path -replace "%USERPROFILE%", $env:USERPROFILE }
        { $_ -match "%LocalAppData%" } { $Path = $Path -replace "%LocalAppData%", $env:LocalAppData }
        { $_ -match "%AppData%" } { $Path = $Path -replace "%AppData%", $env:AppData }
        { $_ -match "%TEMP%" } { $Path = $Path -replace "%TEMP%", $env:Temp }
    }
    Write-Output -InputObject $Path
}

Function Get-AllExceptLatest {
    <#
          .SYNOPSIS
            Returns all sub-folders of a specified path except for the latest folder, based on CreationTime.
        #>
    Param (
        [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True)]
        [Alias("PSPath")]
        [System.String] $Path
    )
    $folders = Get-ChildItem -Path $Path -Directory
    If ($folders.Count -gt 1) {
        $folder = $folders | Sort-Object -Property CreationTime -Descending | Select-Object -First 1
        Write-Output (Get-ChildItem -Path $Path -Exclude $folder.Name)
    }
}

Function Get-TestPath {
    <#
          .SYNOPSIS
            Check whether path includes wildcards in file names
            If so, return parent path, or just return the same path
        #>
    Param (
        [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True)]
        [System.String] $Path
    )
    If ((Split-Path -Path $Path -Leaf) -match "[*?]") {
        $fileList = Split-Path -Path $Path -Parent
    }
    Else {
        $fileList = $Path
    }
    Write-Output -InputObject $fileList
}
#endregion

# Output array, will contain the list of files/folders removed
$LogFile = Join-Path -Path $LogPath -ChildPath $("$($MyInvocation.MyCommand)-$((Get-Date).ToFileTimeUtc()).log")
[System.Array] $fileList = @()

# Record start time
If ($WhatIfPreference -eq $True) {
    $WhatIfPreference = $False
    "[$($MyInvocation.MyCommand)][$(Get-Date -Format FileDateTime)] WhatIf mode" | Out-File -FilePath $LogFile -Append
    $WhatIfPreference = $True
}
Else {
    "[$($MyInvocation.MyCommand)][$(Get-Date -Format FileDateTime)] Delete mode" | Out-File -FilePath $LogFile -Append
}
Write-Verbose -Message "Writing file list to: $LogFile."
If ($Override) { "[$($MyInvocation.MyCommand)][$(Get-Date -Format FileDateTime)] Overide mode enabled" | Out-File -FilePath $LogFile -Append }

# Read the specifed XML document
Try {
    [System.XML.XMLDocument] $xmlDocument = Get-Content -Path $Targets -ErrorAction SilentlyContinue
}
Catch [System.IO.IOException] {
    Write-Warning -Message "$($MyInvocation.MyCommand): failed to read: $Targets."
    Throw $_.Exception.Message
}
Catch [System.Exception] {
    Throw $_
}

If ($xmlDocument -is [System.XML.XMLDocument]) {

    # Select each Target XPath; walk through each target to delete files
    ForEach ($target in (Select-Xml -Xml $xmlDocument -XPath "//Target")) {

        Write-Verbose -Message "Processing target: [$($target.Node.Name)]"
        ForEach ($targetPath in $target.Node.Path) {
            
            # Convert path from XML with environment variable to actual path
            $thisPath = $(ConvertTo-Path -Path $targetPath.innerText)
            Write-Verbose -Message "Processing folder: $thisPath"

            # Get files to delete from Paths and file age; build output array
            If (Test-Path -Path $(Get-TestPath -Path $thisPath) -ErrorAction SilentlyContinue) {

                Switch ($targetPath.Action) {
                    "Prune" {
                        # Get file age from Days value in XML; if -Override used, set $dateFilter to now
                        If ($Override) {
                            $dateFilter = Get-Date
                        }
                        Else {
                            $dateFilter = (Get-Date).AddDays(- $targetPath.Days)
                        }

                        # Construct the file list for this folder and add to the full list for logging
                        Try {
                            $files = Get-ChildItem -Path $thisPath -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -le $dateFilter }
                        }
                        Catch [System.UnauthorizedAccessException] {
                            Write-Warning -Message "$($MyInvocation.MyCommand): Access exception error. Failed to resolve $thisPath."
                        }
                        Catch [System.Exception] {
                            Write-Warning -Message "$($MyInvocation.MyCommand): failed to resolve $thisPath."
                        }
                        Finally {
                            $fileList += $file
                        }

                        # Delete files with support for -WhatIf
                        ForEach ($file in $files) {
                            Try {
                                Remove-Item -Path $file.FullName -Force -Recurse -ErrorAction SilentlyContinue
                            }
                            Catch [System.IO.IOException] {
                                Write-Warning -Message "$($MyInvocation.MyCommand): IO exception error. Failed to remove $($file.FullName)."
                            }
                            Catch [System.UnauthorizedAccessException] {
                                Write-Warning -Message "$($MyInvocation.MyCommand): Access exception error. Failed to remove $($file.FullName)."
                            }
                            Catch [System.Exception] {
                                Write-Warning -Message "$($MyInvocation.MyCommand): failed to remove $($file.FullName)."
                            }
                        }
                    }

                    "Delete" {
                        # Construct the file list for this folder and add to the full list for logging
                        $files = Get-ChildItem -Path $thisPath -Recurse -Force -ErrorAction SilentlyContinue
                        $fileList += $file

                        # Delete the target folder
                        Try {
                            Remove-Item -Path $thisPath -Force -Recurse -ErrorAction SilentlyContinue
                        }
                        Catch [System.IO.IOException] {
                            Write-Warning -Message "$($MyInvocation.MyCommand): IO exception error. Failed to remove $thisPath."
                        }
                        Catch [System.UnauthorizedAccessException] {
                            Write-Warning -Message "$($MyInvocation.MyCommand): Access exception error. Failed to remove $thisPath."
                        }
                        Catch [System.Exception] {
                            Write-Warning -Message "$($MyInvocation.MyCommand): failed to remove $thisPath."
                        }
                    }

                    "Trim" {
                        # Determine sub-folders of the target path to delete
                        $folders = Get-AllExceptLatest -Path $thisPath

                        ForEach ($folder in $folders) {

                            # Construct the file list for this folder and add to the full list for logging
                            $files = Get-ChildItem -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
                            $fileList += $file

                            Try {
                                Remove-Item -Path $folder -Force -Recurse -ErrorAction SilentlyContinue
                            }
                            Catch [System.IO.IOException] {
                                Write-Warning -Message "$($MyInvocation.MyCommand): IO exception error. Failed to remove $folder."
                            }
                            Catch [System.UnauthorizedAccessException] {
                                Write-Warning -Message "$($MyInvocation.MyCommand): Access exception error. Failed to remove $folder."
                            }
                            Catch [System.Exception] {
                                Write-Warning -Message "$($MyInvocation.MyCommand): failed to remove $folder."
                            }
                        }
                    }
                    
                    Default {
                        Write-Warning -Message "[Unable to determine action for $thisPath]"
                    }
                }
            }
        }
    }
}
Else {
    Write-Error -Message "$Targets failed validation."
}

# Output total size of files deleted
If ($fileList.FullName.Count -gt 0) {
    $size = ($fileList | Measure-Object -Sum Length).Sum
    $size = $size / 1MB

    # Write deleted file list out to the log file
    If ($WhatIfPreference -eq $True) { $WhatIfPreference = $False }
    "[$($MyInvocation.MyCommand)][$(Get-Date -Format FileDateTime)] File list start" | Out-File -FilePath $LogFile -Append
    $fileList.FullName | Out-File -FilePath $LogFile -Append
    "[$($MyInvocation.MyCommand)][$(Get-Date -Format FileDateTime)] File list end" | Out-File -FilePath $LogFile -Append
}
Else {
    $size = 0
}
Write-Verbose -Message "Total file size deleted: $size MB."

# Prune old log files. Keep last number of logs: $KeepLogs
$Logs = Get-ChildItem -Path $LogPath -Filter $("$($MyInvocation.MyCommand)-*.log")
If ($Logs.Count -gt $KeepLog) {
    $Logs | Sort-Object -Property LastWriteTime | Select-Object -First ($Logs.Count - $KeepLog) | Remove-Item -Force
    Write-Verbose -Message "Removed log files: $($Logs.Count - $KeepLog)."
}

# Return the size of the deleted files in MiB to the pipeline
Write-Output -InputObject "Deleted: $size MB."
