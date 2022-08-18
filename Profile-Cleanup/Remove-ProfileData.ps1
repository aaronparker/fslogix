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
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High", HelpUri = "https://stealthpuppy.com/fslogix/profilecleanup/")]
Param (
    [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript( { if (Test-Path $_ -PathType "Leaf") { $True } else { Throw "Cannot find targets file: $_." } })]
    [Alias("Path", "Xml")]
    [System.String] $Targets,

    [Parameter(Mandatory = $False, Position = 1)]
    [ValidateScript( { if (Test-Path -Path $_ -PathType "Container") { $True } else { Throw "Cannot find log file directory: $_." } })]
    [System.String] $LogPath = (Resolve-Path -Path $env:LocalAppData),

    [Parameter(Mandatory = $False)]
    [System.Management.Automation.SwitchParameter] $Override,

    [Parameter(Mandatory = $False)]
    [ValidateRange(1, 256)]
    [System.Int32] $KeepLog = 30
)

begin {

    #region Functions
    function Write-Log ($Message) {
        if (Test-Path -Path $(Split-Path -Path $global:LogFile -Parent) -ErrorAction "SilentlyContinue") {}
        else {
            $params = @{
                Path        = (Split-Path -Path $global:LogFile -Parent)
                ItemType    = "Directory"
                ErrorAction = "SilentlyContinue"
                Confirm      = $False
            }
            New-Item @params | Out-Null
        }

        try {
            $TimeStamp = "[{0:dd/MM/yyyy} {0:HH:mm:ss}]" -f (Get-Date)
            Write-Verbose -Message "$TimeStamp : $Message"
            $params = @{
                FilePath    = $global:LogFile
                Append      = $True
                Encoding    = "Utf8"
                Confirm      = $False
                ErrorAction = "SilentlyContinue"
            }
            "$($TimeStamp): $Message" | Out-File @params
        }
        catch {
            Write-Error -Message "Failed to add entry to $global:LogFile."
        }
    }

    function ConvertTo-Path {
        <#
          .SYNOPSIS
            Replaces environment variables in strings with actual path
        #>
        Param (
            [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True)]
            [System.String] $Path
        )
        Process {
            switch ($Path) {
                { $_ -match "%USERPROFILE%" } { $Path = $Path -replace "%USERPROFILE%", $env:USERPROFILE }
                { $_ -match "%LocalAppData%" } { $Path = $Path -replace "%LocalAppData%", $env:LocalAppData }
                { $_ -match "%AppData%" } { $Path = $Path -replace "%AppData%", $env:AppData }
                { $_ -match "%TEMP%" } { $Path = $Path -replace "%TEMP%", $env:Temp }
            }
            Write-Output -InputObject $Path
        }
    }

    function Convert-Size {
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

    function Get-AllExceptLatest {
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
            if ($folders.Count -gt 1) {
                $folder = $folders | Sort-Object -Property CreationTime -Descending | Select-Object -First 1
                Write-Output (Get-ChildItem -Path $Path -Exclude $folder.Name)
            }
        }
    }

    function Get-TestPath {
        <#
            .SYNOPSIS
            Check whether path includes wildcards in file names
            If so, return parent path, or just return the same path
        #>
        param (
            [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True)]
            [System.String] $Path
        )
        process {
            if ((Split-Path -Path $Path -Leaf) -match "[*?]") {
                $List = Split-Path -Path $Path -Parent
            }
            else {
                $List = $Path
            }
            Write-Output -InputObject $List
        }
    }
    #endregion

    # Output array, will contain the list of files/folders removed
    $global:LogFile = Join-Path -Path $LogPath -ChildPath $("$($MyInvocation.MyCommand)-$((Get-Date).ToFileTimeUtc()).log")
    Remove-Variable -Name "fileList" -ErrorAction "SilentlyContinue"
    $fileList = New-Object -TypeName "System.Collections.ArrayList"

    # Measure time taken to gather data
    $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    if ($WhatIfPreference -eq $True) {
        $WhatIfPreference = $False
        Write-Log -Message "WhatIf mode."
        $WhatIfPreference = $True
    }
    else {
        Write-Log -Message "Delete mode."
    }
    Write-Verbose -Message "Writing file list to: $LogFile."
    if ($Override) { Write-Log -Message "Override mode enabled." }
}

process {
    # Read the specified XML document
    try {
        [System.XML.XMLDocument] $xmlDocument = Get-Content -Path $Targets -ErrorAction "SilentlyContinue"
    }
    catch {
        Write-Warning -Message "Failed to read: $Targets."
        Write-Log -Message "Failed to read: $Targets."
        throw $_.Exception.Message
    }

    if ($xmlDocument -is [System.XML.XMLDocument]) {

        # Select each Target XPath; walk through each target to delete files
        foreach ($target in (Select-Xml -Xml $xmlDocument -XPath "//Target")) {

            Write-Verbose -Message "Processing target: [$($target.Node.Name)]"
            foreach ($targetPath in $target.Node.Path) {

                # Convert path from XML with environment variable to actual path
                $thisPath = $(ConvertTo-Path -Path $targetPath.innerText)
                Write-Verbose -Message "Processing folder: $thisPath"

                # Get files to delete from Paths and file age; build output array
                if (Test-Path -Path $(Get-TestPath -Path $thisPath) -ErrorAction "SilentlyContinue") {

                    switch ($targetPath.Action) {
                        "Prune" {
                            # Get file age from Days value in XML; if -Override used, set $dateFilter to now
                            if ($Override) {
                                $dateFilter = Get-Date
                            }
                            else {
                                $dateFilter = (Get-Date).AddDays(- $targetPath.Days)
                            }

                            # Construct the file list for this folder and add to the full list for logging
                            try {
                                $params = @{
                                    Path        = $thisPath
                                    Exclude     = "desktop.ini"
                                    Recurse     = $True
                                    Force       = $True
                                    ErrorAction = "SilentlyContinue"
                                }
                                $files = Get-ChildItem @params | Where-Object { $_.LastWriteTime -le $dateFilter }
                            }
                            catch [System.UnauthorizedAccessException] {
                                Write-Warning -Message "Access exception error. Failed to access $thisPath."
                                Write-Log -Message "Access exception error. Failed to access $thisPath."
                            }
                            catch [System.Exception] {
                                Write-Warning -Message "failed to resolve $thisPath."
                                Write-Log -Message "Failed to resolve $thisPath."
                            }
                            finally {
                                $fileList.Add($files) | Out-Null
                            }

                            # Delete files with support for -WhatIf
                            foreach ($file in $files) {
                                if ($PSCmdlet.ShouldProcess($file.FullName, "Prune")) {
                                    try {
                                        Remove-Item -Path $file.FullName -Force -Recurse -ErrorAction "SilentlyContinue"
                                    }
                                    catch [System.IO.IOException] {
                                        Write-Warning -Message "IO exception error. Failed to remove $($file.FullName)."
                                        Write-Log -Message "IO exception error. Failed to remove $($file.FullName)."
                                    }
                                    catch [System.UnauthorizedAccessException] {
                                        Write-Warning -Message "Access exception error. Failed to remove $($file.FullName)."
                                        Write-Log -Message "Access exception error. Failed to remove $($file.FullName)."
                                    }
                                    catch [System.Exception] {
                                        Write-Warning -Message "failed to remove $($file.FullName)."
                                        Write-Log -Message "Failed to remove $($file.FullName)."
                                    }
                                }
                            }
                        }

                        "Delete" {
                            # Construct the file list for this folder and add to the full list for logging
                            $files = Get-ChildItem -Path $thisPath -Recurse -Force -ErrorAction "SilentlyContinue"
                            $fileList.Add($files) | Out-Null

                            # Delete the target folder
                            if ($PSCmdlet.ShouldProcess($thisPath, "Delete")) {
                                try {
                                    Remove-Item -Path $thisPath -Force -Recurse -ErrorAction "SilentlyContinue"
                                }
                                catch [System.IO.IOException] {
                                    Write-Warning -Message "IO exception error. Failed to remove $thisPath."
                                    Write-Log -Message "IO exception error. Failed to remove $thisPath."
                                }
                                catch [System.UnauthorizedAccessException] {
                                    Write-Warning -Message "Access exception error. Failed to remove $thisPath."
                                    Write-Log -Message "Access exception error. Failed to remove $thisPath."
                                }
                                catch [System.Exception] {
                                    Write-Warning -Message "failed to remove $thisPath."
                                    Write-Log -Message "failed to remove $thisPath."
                                }
                            }
                        }

                        "Trim" {
                            # Determine sub-folders of the target path to delete
                            $folders = Get-AllExceptLatest -Path $thisPath
                            foreach ($folder in $folders) {

                                # Construct the file list for this folder and add to the full list for logging
                                $files = Get-ChildItem -Path $folder -Recurse -Force -ErrorAction "SilentlyContinue"
                                $fileList.Add($files) | Out-Null

                                if ($PSCmdlet.ShouldProcess($folder, "Trim")) {
                                    try {
                                        Remove-Item -Path $folder -Force -Recurse -ErrorAction "SilentlyContinue"
                                    }
                                    catch [System.IO.IOException] {
                                        Write-Warning -Message "IO exception error. Failed to remove $folder."
                                        Write-Log -Message "IO exception error. Failed to remove $folder."
                                    }
                                    catch [System.UnauthorizedAccessException] {
                                        Write-Warning -Message "Access exception error. Failed to remove $folder."
                                        Write-Log -Message "Access exception error. Failed to remove $folder."
                                    }
                                    catch [System.Exception] {
                                        Write-Warning -Message "failed to remove $folder."
                                        Write-Log -Message "failed to remove $folder."
                                    }
                                }
                            }
                        }

                        default {
                            Write-Warning -Message "[Unable to determine action for $thisPath]"
                            Write-Log -Message "Unable to determine action for $thisPath."
                        }
                    }
                }
            }
        }
    }
    else {
        Write-Error -Message "$Targets failed XML validation. Aborting script."
        Write-Log -Message "$Targets failed validation. Aborting script."
    }

    # Output total size of files deleted
    if ($fileList.FullName.Count -gt 0) {

        Remove-Variable -Name "fileSize" -ErrorAction "SilentlyContinue"
        foreach ($item in $fileList) {
            foreach ($file in $item) {
                $fileSize += $file.Length
                $fileCount += 1
            }
        }
        Remove-Variable -Name "sizeMiB" -ErrorAction "SilentlyContinue"
        $sizeMiB = Convert-Size -From "B" -To "MiB" -Value $fileSize

        # Write deleted file list out to the log file
        if ($WhatIfPreference -eq $True) { $WhatIfPreference = $False }
        Write-Log -Message " File list start:"
        Write-Log -Message ($fileList.FullName -join "`n")
        Write-Log -Message " File list end."
    }
    else {
        $sizeMiB = 0
    }
    Write-Log -Message "Total file size deleted $sizeMiB MiB."

    # Return the size of the deleted files in MiB to the pipeline
    $PSObject = [PSCustomObject] @{
        Files   = $fileCount
        Deleted = "$sizeMiB MiB"
    }
    Write-Output -InputObject $PSObject
}

end {
    # Stop time recording
    $stopWatch.Stop()
    Write-Verbose -Message "Script took $($stopWatch.Elapsed.TotalMilliseconds) ms to complete."
    Write-Log -Message "Time to complete $($stopWatch.Elapsed.TotalMilliseconds) ms."

    # Prune old log files. Keep last number of logs: $KeepLogs
    $Logs = Get-ChildItem -Path $LogPath -Filter $("$($MyInvocation.MyCommand)-*.log")
    if ($Logs.Count -gt $KeepLog) {
        $Logs | Sort-Object -Property "LastWriteTime" | Select-Object -First ($Logs.Count - $KeepLog) | Remove-Item -Force
        Write-Verbose -Message "Removed log files: $($Logs.Count - $KeepLog)."
    }
}
