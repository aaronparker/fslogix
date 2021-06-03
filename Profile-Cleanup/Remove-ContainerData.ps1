#Requires -Version 2
#Requires -PSEdition Desktop
#Requires -RunAsAdministrator
#Requires -Modules "Hyper-V"
#Requires -Modules "FsLogix.PowerShell.Disk"
<#
    .SYNOPSIS
        Removes files and folders in an FSLogix Profile Container to reduce profile size.

    .DESCRIPTION
        Reads a list of files and folders from an XML file to delete data based on age.
        The script reads an XML file that defines a list of files and folders to prune from a Profile Container. Ensure that the container is not mounted before running the script.
        Supports -WhatIf and -Verbose output and returns a list of files removed from the container.

    .PARAMETER Path
        Target path that hosts the FSLogix Profile Containers.
    
    .PARAMETER Targets
        Path to an XML file that defines the Contianer profile paths to prune and delete

    .PARAMETER MinimumSizeInMB
        Only select Profile Containers from Path, if the container is over the minimum size.

    .PARAMETER LogPath
        Path to storing a log file for files that are removed from each Container.

    .PARAMETER Override
        Override the Days value listed for each Path with action Prune, in the XML file resulting in the forced removal of all files in the path.

    .EXAMPLE
        C:\> .\Remove-ContainerData.ps1 -Path \\server\Containers -Targets .\targets.xml -WhatIf

        Description:
        Reads targets.xml that defines a list of files and folders to delete from Profile Containers contained in \\server\Containers.
        Reports on the files/folders to delete without deleting them.

    .EXAMPLE
        C:\> .\Remove-ContainerData.ps1 -Path \\server\Containers -Targets .\targets.xml -Confirm:$False -Verbose

        Description:
        Reads targets.xml that defines a list of files and folders to delete from Profile Containers contained in \\server\Containers.
        Deletes the targets and reports on the total size of files removed for each Container.

    .EXAMPLE
        C:\> .\Remove-ContainerData.ps1 -Path \\server\Containers -Targets .\targets.xml -MinimumSizeInMB 800 -LogPath C:\Logs -Confirm:$False -Verbose

        Description:
        Reads targets.xml that defines a list of files and folders to delete from Profile Containers contained in \\server\Containers.
        Selects only Containers in Path that are 800 MB or larger. Stores a log file for each container in C:\Logs.
        Deletes the targets and reports on the total size of files removed for each Container.

    .INPUTS
        XML file that defines target files and folders to remove.

    .OUTPUTS
        [System.String]

    .NOTES
        Windows profiles can be cleaned up to reduce profile size and bloat.
        Use with traditional profile solutions to clean up profiles or with Container-based solution to keep Container sizes to minimum.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', `
        HelpUri = "https://stealthpuppy.com/fslogix/containercleanup/")]
[OutputType([System.String])]
Param (
    [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript( { If (Test-Path $_ -PathType 'Container') { $True } Else { Throw "Cannot find path $_" } })]
    [System.String[]] $Path,

    [Parameter(Mandatory = $True, Position = 1, ValueFromPipelineByPropertyName)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript( { If (Test-Path $_ -PathType 'Leaf') { $True } Else { Throw "Cannot find file $_" } })]
    [System.String] $Targets,

    [Parameter(Mandatory = $False, Position = 2)]
    [System.Int32] $MinimumSizeInMB = 0,

    [Parameter(Mandatory = $False, Position = 3)]
    [System.Management.Automation.SwitchParameter] $Override,

    [Parameter(Mandatory = $False, Position = 3)]
    [ValidateScript( { If (Test-Path $_ -PathType 'Container') { $True } Else { Throw "Cannot find path $_" } })]
    [System.String] $LogPath = $PWD
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
        { $_ -match "%USERPROFILE%" } { $Path = $Path -replace "%USERPROFILE%", "Profile" }
        { $_ -match "%LocalAppData%" } { $Path = $Path -replace "%LocalAppData%", "Profile\AppData\Local" }
        { $_ -match "%AppData%" } { $Path = $Path -replace "%AppData%", "Profile\AppData\Roaming" }
        { $_ -match "%TEMP%" } { $Path = $Path -replace "%TEMP%", "Profile\AppData\Local\Temp" }
    }
    Write-Output -InputObject $Path
}

Function Convert-Size {
    <#
            .SYNOPSIS
                Converts computer data sizes between one format and another. 
            .DESCRIPTION
                This function handles conversion from any-to-any (e.g. Bits, Bytes, KB, KiB, MB,
                MiB, etc.) It also has the ability to specify the precision of digits you want to
                recieve as the output.
        
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


# Measure time taken to gather data
$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
Write-Verbose -Message "$($MyInvocation.MyCommand): This script requires a custom version of FsLogix.PowerShell.Disk."
Write-Verbose -Message "$($MyInvocation.MyCommand): Download the module from here: https://github.com/aaronparker/fslogix/tree/main/Modules/Fslogix.Powershell.Disk"

# Read the specifed XML document
Try {
    [System.XML.XMLDocument] $xmlDocument = Get-Content -Path $Targets -ErrorAction SilentlyContinue
}
Catch [System.IO.IOException] {
    Write-Warning -Message "$($MyInvocation.MyCommand): failed to read: $Targets."
    Throw $_.Exception.Message
}
Catch [System.Exception] {
    Throw $_.Exception.Message
}

If ($xmlDocument -is [System.XML.XMLDocument]) {

    ForEach ($folder in $Path) {
        # Get Profile Containers from the target path; Only select containers over the specified minimum size (default 0)
        $Containers = Get-ChildItem -Path $folder -Recurse -Filter "Profile*.vhdx" | `
                Where-Object { $_.Length -gt (Convert-Size -From MB -To KB -Value $MinimumSizeInMB) }

        # Step through each Container
        ForEach ($container in $Containers) {

            # Log file for this container
            $LogFile = Join-Path -Path $LogPath -ChildPath $($(Split-Path -Path $container.FullName -Leaf) + $((Get-Date).ToFileTimeUtc()) + ".log")
            Write-Verbose -Message "$($MyInvocation.MyCommand): Writing file list to $LogFile."

            If ($WhatIfPreference -eq $True) {
                $WhatIfPreference = $False
                "[$($MyInvocation.MyCommand)][$(Get-Date -Format FileDateTime)] WhatIf mode" | Out-File -FilePath $LogFile -Append
                $WhatIfPreference = $True
            }
            Else {
                "[$($MyInvocation.MyCommand)][$(Get-Date -Format FileDateTime)] Delete mode" | Out-File -FilePath $LogFile -Append
            }
        
            # Output array, will contain the list of files/folders removed
            $fileList = New-Object -TypeName System.Collections.ArrayList

            # Mount the Container
            Write-Verbose -Message "$($MyInvocation.MyCommand): Mounting $($container.FullName) with Add-FslDriveLetter."
            $MountPath = Add-FslDriveLetter -Path $container.FullName -Passthru

            # Prune the container
            If ($Null -ne $MountPath) {
                Write-Verbose -Message "$($MyInvocation.MyCommand): Container mounted at: $MountPath."

                # Select each Target XPath; walk through each target to delete files
                ForEach ($target in (Select-Xml -Xml $xmlDocument -XPath "//Target")) {

                    Write-Verbose -Message "$($MyInvocation.MyCommand): Processing target: [$($target.Node.Name)]"
                    ForEach ($targetPath in $target.Node.Path) {
            
                        # Convert path from XML with environment variable to actual path
                        $thisPath = Join-Path -Path $MountPath -ChildPath $(ConvertTo-Path -Path $targetPath.innerText)
                        Write-Verbose -Message "$($MyInvocation.MyCommand): Processing folder: $thisPath"

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
                                    $files = Get-ChildItem -Path $thisPath -Recurse -Force -ErrorAction SilentlyContinue -Exclude "desktop.ini" | `
                                            Where-Object { $_.LastWriteTime -le $dateFilter }
                                    $fileList.Add($files) | Out-Null

                                    # Delete files with support for -WhatIf
                                    ForEach ($file in $files) {
                                        If ($pscmdlet.ShouldProcess($file.FullName, "Prune")) {
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
                                }

                                "Delete" {
                                    # Construct the file list for this folder and add to the full list for logging
                                    $files = Get-ChildItem -Path $thisPath -Recurse -Force -ErrorAction SilentlyContinue
                                    $fileList.Add($files) | Out-Null

                                    # Delete the target folder
                                    If ($pscmdlet.ShouldProcess($thisPath, "Delete")) {
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
                                }

                                "Trim" {
                                    # Determine sub-folders of the target path to delete
                                    $folders = Get-AllExceptLatest -Path $thisPath

                                    ForEach ($folder in $folders) {

                                        # Construct the file list for this folder and add to the full list for logging
                                        $files = Get-ChildItem -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
                                        $fileList.Add($files) | Out-Null

                                        If ($pscmdlet.ShouldProcess($folder, "Trim")) {
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
                                }
                    
                                Default {
                                    Write-Warning -Message "$($MyInvocation.MyCommand): [Unable to determine action for $thisPath]"
                                }
                            }
                        }
                    }
                }
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
                $fileList.FullName | Out-File -FilePath $LogFile -Append -ErrorAction SilentlyContinue
                "[$($MyInvocation.MyCommand)][$(Get-Date -Format FileDateTime)] File list end" | Out-File -FilePath $LogFile -Append
            }
            Else {
                $sizeMiB = 0
            }
            Write-Verbose -Message "$($MyInvocation.MyCommand): Total file size deleted: $size MiB."

            # Dismount the container
            Write-Verbose -Message "$($MyInvocation.MyCommand): Dismounting $($container.FullName) with Dismount-FslDisk."
            $Dismount = $True
            Try {
                Dismount-FslDisk -Path $container.FullName -ErrorAction Stop | Out-Null
            }
            Catch [System.Exception] {
                Write-Warning -Message "$($MyInvocation.MyCommand): failed to dismount $($container.FullName)."
                $Dismount = $False
            }

            # Return the size of the deleted files in MiB to the pipeline
            $PSObject = [PSCustomObject]@{
                Path       = $container.FullName
                Dismounted = $Dismount
                Files      = $fileCount
                Deleted    = "$sizeMiB MiB"
            }
            Write-Output -InputObject $PSObject
        }
    }
}
Else {
    Write-Error -Message "$($MyInvocation.MyCommand): $Targets failed XML validation. Aborting script."
}

# Stop time recording
$stopWatch.Stop()
"[$($MyInvocation.MyCommand)][$(Get-Date -Format FileDateTime)] Time to complete $($stopWatch.Elapsed.TotalMilliseconds) ms" | Out-File -FilePath $LogFile -Append
"[$($MyInvocation.MyCommand)][$(Get-Date -Format FileDateTime)] Total file size deleted $size MiB" | Out-File -FilePath $LogFile -Append
Write-Verbose -Message "$($MyInvocation.MyCommand): Script took $($stopWatch.Elapsed.TotalMilliseconds) ms to complete."
