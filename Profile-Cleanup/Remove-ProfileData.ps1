#Requires -Version 2
#Requires -PSEdition Desktop
<#
    .SYNOPSIS
        Removes files and folders in the user profile to reduce profile size.

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

    .OUTPUTS
        [System.String]

    .NOTES
        Windows profiles can be cleaned up to reduce profile size and bloat.
        Use with traditional profile solutions to clean up profiles or with Container-based solution to keep Container sizes to minimum.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', HelpUri = 'https://docs.stealthpuppy.com/docs/fslogix/profile')]
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

Begin {

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
        Process {
            Switch ($Path) {
                { $_ -match "%USERPROFILE%" } { $Path = $Path -replace "%USERPROFILE%", $env:USERPROFILE }
                { $_ -match "%LocalAppData%" } { $Path = $Path -replace "%LocalAppData%", $env:LocalAppData }
                { $_ -match "%AppData%" } { $Path = $Path -replace "%AppData%", $env:AppData }
                { $_ -match "%TEMP%" } { $Path = $Path -replace "%TEMP%", $env:Temp }
            }
            Write-Output -InputObject $Path
        }
    }

    Function Convert-Size {
        <#
            .SYNOPSIS
                Converts computer data sizes between one format and another.
            .DESCRIPTION
                This function handles conversion from any-to-any (e.g. Bits, Bytes, KB, KiB, MB,
                MiB, etc.) It also has the ability to specify the precision of digits you want to
                receive as the output.

                International System of Units (SI) Binary and Standard
                https://physics.nist.gov/cuu/Units/binary.html
                https://en.wikipedia.org/wiki/Binary_prefix
            .NOTES
                Author: Techibee posted on July 7, 2014
                Modified By: Void, modified on December 9, 2016
            .LINK
                https://techibee.com/powershell/convert-from-any-to-any-bytes-kb-mb-gb-tb-using-powershell/2376
            .EXAMPLE
                Convert-Size -From KB -To GB -Value 1024
                0.001

                Convert from Kilobyte to Gigabyte (Base 10)
            .EXAMPLE
                Convert-Size -From GB -To GiB -Value 1024
                953.6743

                Convert from Gigabyte (Base 10) to GibiByte (Base 2)
            .EXAMPLE
                Convert-Size -From TB -To TiB -Value 1024 -Precision 2
                931.32

                Convert from Terabyte (Base 10) to Tebibyte (Base 2) with only 2 digits after the decimal
        #>
        [OutputType([System.Double])]
        Param(
            [ValidateSet("b", "B", "KB", "KiB", "MB", "MiB", "GB", "GiB", "TB", "TiB", "PB", "PiB", "EB", "EiB", "ZB", "ZiB", "YB", "YiB")]
            [Parameter(Mandatory = $true)]
            [System.String] $From,

            [ValidateSet("b", "B", "KB", "KiB", "MB", "MiB", "GB", "GiB", "TB", "TiB", "PB", "PiB", "EB", "EiB", "ZB", "ZiB", "YB", "YiB")]
            [Parameter(Mandatory = $true)]
            [System.String] $To,

            [Parameter(Mandatory = $true)]
            [System.Double] $Value,

            [System.Int32] $Precision = 2
        )
        # Convert the supplied value to Bytes
        switch -casesensitive ($From) {
            "b" { $value = $value / 8 }
            "B" { $value = $Value }
            "KB" { $value = $Value * 1000 }
            "KiB" { $value = $value * 1024 }
            "MB" { $value = $Value * 1000000 }
            "MiB" { $value = $value * 1048576 }
            "GB" { $value = $Value * 1000000000 }
            "GiB" { $value = $value * 1073741824 }
            "TB" { $value = $Value * 1000000000000 }
            "TiB" { $value = $value * 1099511627776 }
            "PB" { $value = $value * 1000000000000000 }
            "PiB" { $value = $value * 1125899906842624 }
            "EB" { $value = $value * 1000000000000000000 }
            "EiB" { $value = $value * 1152921504606850000 }
            "ZB" { $value = $value * 1000000000000000000000 }
            "ZiB" { $value = $value * 1180591620717410000000 }
            "YB" { $value = $value * 1000000000000000000000000 }
            "YiB" { $value = $value * 1208925819614630000000000 }
        }
        # Convert the number of Bytes to the desired output
        switch -casesensitive ($To) {
            "b" { $value = $value * 8 }
            "B" { return $value }
            "KB" { $Value = $Value / 1000 }
            "KiB" { $value = $value / 1024 }
            "MB" { $Value = $Value / 1000000 }
            "MiB" { $Value = $Value / 1048576 }
            "GB" { $Value = $Value / 1000000000 }
            "GiB" { $Value = $Value / 1073741824 }
            "TB" { $Value = $Value / 1000000000000 }
            "TiB" { $Value = $Value / 1099511627776 }
            "PB" { $Value = $Value / 1000000000000000 }
            "PiB" { $Value = $Value / 1125899906842624 }
            "EB" { $Value = $Value / 1000000000000000000 }
            "EiB" { $Value = $Value / 1152921504606850000 }
            "ZB" { $value = $value / 1000000000000000000000 }
            "ZiB" { $value = $value / 1180591620717410000000 }
            "YB" { $value = $value / 1000000000000000000000000 }
            "YiB" { $value = $value / 1208925819614630000000000 }
        }
        [Math]::Round($value, $Precision, [MidPointRounding]::AwayFromZero)
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
        Process {
            $folders = Get-ChildItem -Path $Path -Directory
            If ($folders.Count -gt 1) {
                $folder = $folders | Sort-Object -Property CreationTime -Descending | Select-Object -First 1
                Write-Output (Get-ChildItem -Path $Path -Exclude $folder.Name)
            }
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
        Process {
            If ((Split-Path -Path $Path -Leaf) -match "[*?]") {
                $fileList = Split-Path -Path $Path -Parent
            }
            Else {
                $fileList = $Path
            }
            Write-Output -InputObject $fileList
        }
    }
    #endregion

    # Output array, will contain the list of files/folders removed
    $LogFile = Join-Path -Path $LogPath -ChildPath $("$($MyInvocation.MyCommand)-$((Get-Date).ToFileTimeUtc()).log")
    $fileList = New-Object -TypeName "System.Collections.ArrayList"

    # Measure time taken to gather data
    $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    If ($WhatIfPreference -eq $True) {
        $WhatIfPreference = $False
        "[$($MyInvocation.MyCommand)][$(Get-Date -Format FileDateTime)] WhatIf mode" | Out-File -FilePath $LogFile -Append
        $WhatIfPreference = $True
    }
    Else {
        "[$($MyInvocation.MyCommand)][$(Get-Date -Format FileDateTime)] Delete mode" | Out-File -FilePath $LogFile -Append
    }
    Write-Verbose -Message "Writing file list to: $LogFile."
    If ($Override) { "[$($MyInvocation.MyCommand)][$(Get-Date -Format FileDateTime)] Override mode enabled" | Out-File -FilePath $LogFile -Append }
}

Process {
    # Read the specified XML document
    Try {
        [System.XML.XMLDocument] $xmlDocument = Get-Content -Path $Targets -ErrorAction SilentlyContinue
    }
    Catch {
        Write-Warning -Message "$($MyInvocation.MyCommand): failed to read: $Targets."
        Throw $_.Exception.Message
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
                                Write-Warning -Message "$($MyInvocation.MyCommand): Access exception error. Failed to access $thisPath."
                                "[$($MyInvocation.MyCommand)][$(Get-Date -Format FileDateTime)] Access exception error. Failed to access $thisPath." | Out-File -FilePath $LogFile -Append
                            }
                            Catch [System.Exception] {
                                Write-Warning -Message "$($MyInvocation.MyCommand): failed to resolve $thisPath."
                                "[$($MyInvocation.MyCommand)][$(Get-Date -Format FileDateTime)] Failed to resolve $thisPath." | Out-File -FilePath $LogFile -Append
                            }
                            Finally {
                                $fileList.Add($files) | Out-Null
                            }

                            # Delete files with support for -WhatIf
                            ForEach ($file in $files) {
                                If ($PSCmdlet.ShouldProcess($file.FullName, "Prune")) {
                                    Try {
                                        Remove-Item -Path $file.FullName -Force -Recurse -ErrorAction SilentlyContinue
                                    }
                                    Catch [System.IO.IOException] {
                                        Write-Warning -Message "$($MyInvocation.MyCommand): IO exception error. Failed to remove $($file.FullName)."
                                        "$($MyInvocation.MyCommand): IO exception error. Failed to remove $($file.FullName)." | Out-File -FilePath $LogFile
                                    }
                                    Catch [System.UnauthorizedAccessException] {
                                        Write-Warning -Message "$($MyInvocation.MyCommand): Access exception error. Failed to remove $($file.FullName)."
                                        "$($MyInvocation.MyCommand): Access exception error. Failed to remove $($file.FullName)." | Out-File -FilePath $LogFile
                                    }
                                    Catch [System.Exception] {
                                        Write-Warning -Message "$($MyInvocation.MyCommand): failed to remove $($file.FullName)."
                                        "$($MyInvocation.MyCommand): failed to remove $($file.FullName)." | Out-File -FilePath $LogFile
                                    }
                                }
                            }
                        }

                        "Delete" {
                            # Construct the file list for this folder and add to the full list for logging
                            $files = Get-ChildItem -Path $thisPath -Recurse -Force -ErrorAction SilentlyContinue
                            $fileList.Add($files) | Out-Null

                            # Delete the target folder
                            If ($PSCmdlet.ShouldProcess($thisPath, "Delete")) {
                                Try {
                                    Remove-Item -Path $thisPath -Force -Recurse -ErrorAction SilentlyContinue
                                }
                                Catch [System.IO.IOException] {
                                    Write-Warning -Message "$($MyInvocation.MyCommand): IO exception error. Failed to remove $thisPath."
                                    "$($MyInvocation.MyCommand): IO exception error. Failed to remove $thisPath." | Out-File -FilePath $LogFile
                                }
                                Catch [System.UnauthorizedAccessException] {
                                    Write-Warning -Message "$($MyInvocation.MyCommand): Access exception error. Failed to remove $thisPath."
                                    "$($MyInvocation.MyCommand): Access exception error. Failed to remove $thisPath." | Out-File -FilePath $LogFile
                                }
                                Catch [System.Exception] {
                                    Write-Warning -Message "$($MyInvocation.MyCommand): failed to remove $thisPath."
                                    "$($MyInvocation.MyCommand): failed to remove $thisPath." | Out-File -FilePath $LogFile
                                }
                            }
                        }

                        "Trim" {
                            # Determine sub-folders of the target path to delete
                            $folders = Get-AllExceptLatest -Path $thisPath
                            ForEach ($folder in $folders) {

                                # Construct the file list for this folder and add to the full list for logging
                                $files = Get-ChildItem -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
                                $fileList.Add($files) | Out-Null

                                If ($PSCmdlet.ShouldProcess($folder, "Trim")) {
                                    Try {
                                        Remove-Item -Path $folder -Force -Recurse -ErrorAction SilentlyContinue
                                    }
                                    Catch [System.IO.IOException] {
                                        Write-Warning -Message "$($MyInvocation.MyCommand): IO exception error. Failed to remove $folder."
                                        "$($MyInvocation.MyCommand): IO exception error. Failed to remove $folder." | Out-File -FilePath $LogFile
                                    }
                                    Catch [System.UnauthorizedAccessException] {
                                        Write-Warning -Message "$($MyInvocation.MyCommand): Access exception error. Failed to remove $folder."
                                        "$($MyInvocation.MyCommand): Access exception error. Failed to remove $folder." | Out-File -FilePath $LogFile
                                    }
                                    Catch [System.Exception] {
                                        Write-Warning -Message "$($MyInvocation.MyCommand): failed to remove $folder."
                                        "$($MyInvocation.MyCommand): failed to remove $folder." | Out-File -FilePath $LogFile
                                    }
                                }
                            }
                        }

                        Default {
                            Write-Warning -Message "$($MyInvocation.MyCommand): [Unable to determine action for $thisPath]"
                        }
                    }
                }
            }
        }
    }
    Else {
        Write-Error -Message "$($MyInvocation.MyCommand): $Targets failed XML validation. Aborting script."
        "[$($MyInvocation.MyCommand)][$(Get-Date -Format FileDateTime)]$Targets failed validation" | Out-File -FilePath $LogFile -Append
    }

    # Output total size of files deleted
    If ($fileList.FullName.Count -gt 0) {
        #$fileSize = ($fileList | Measure-Object -Sum Length).Sum
        # Work around previous approach to calculating size not working
        ForEach ($item in $fileList) {
            ForEach ($file in $item) {
                $fileSize += $file.Length
                $fileCount += 1
            }
        }
        $sizeMiB = Convert-Size -From B -To MiB -Value $fileSize

        # Write deleted file list out to the log file
        If ($WhatIfPreference -eq $True) { $WhatIfPreference = $False }
        "[$($MyInvocation.MyCommand)][$(Get-Date -Format FileDateTime)] File list start" | Out-File -FilePath $LogFile -Append
        $fileList.FullName | Out-File -FilePath $LogFile -Append
        "[$($MyInvocation.MyCommand)][$(Get-Date -Format FileDateTime)] File list end" | Out-File -FilePath $LogFile -Append
    }
    Else {
        $sizeMiB = 0
    }
    "[$($MyInvocation.MyCommand)][$(Get-Date -Format FileDateTime)] Total file size deleted $sizeMiB MiB" | Out-File -FilePath $LogFile -Append

    # Return the size of the deleted files in MiB to the pipeline
    $PSObject = [PSCustomObject]@{
        Files   = $fileCount
        Deleted = "$sizeMiB MiB"
    }
    Write-Output -InputObject $PSObject
}

End {
    # Stop time recording
    $stopWatch.Stop()
    Write-Verbose -Message "Script took $($stopWatch.Elapsed.TotalMilliseconds) ms to complete."
    "[$($MyInvocation.MyCommand)][$(Get-Date -Format FileDateTime)] Time to complete $($stopWatch.Elapsed.TotalMilliseconds) ms" | Out-File -FilePath $LogFile -Append

    # Prune old log files. Keep last number of logs: $KeepLogs
    $Logs = Get-ChildItem -Path $LogPath -Filter $("$($MyInvocation.MyCommand)-*.log")
    If ($Logs.Count -gt $KeepLog) {
        $Logs | Sort-Object -Property LastWriteTime | Select-Object -First ($Logs.Count - $KeepLog) | Remove-Item -Force
        Write-Verbose -Message "$($MyInvocation.MyCommand): Removed log files: $($Logs.Count - $KeepLog)."
    }
}
