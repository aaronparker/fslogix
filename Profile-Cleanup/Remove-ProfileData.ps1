#Requires -Version 2
#Requires -PSEdition Desktop
<#
    .SYNOPSIS
    Removes files and folders in the user profile to reduce profile size.

    .DESCRIPTION
    Reads a list of files and folders from an XML file to delete data based on age.
    The script reads an XML file that defines a list of files and folders to remove to reduce profile size.
    Supports -WhatIf and -Verbose output and returns a list of files removed from the profile.

    .PARAMETER Targets
        Path to an XML file that defines the profile paths to prune and delete

    .PARAMETER LogFile
        Path to file for logging all files that are removed.

    .PARAMETER Override
        Override the Days value listed for each Path with action Prune, in the XML file resulting in the forced removal of all files in the path.

    .EXAMPLE
    C:\> .\$($MyInvocation.MyCommand).ps1 -Targets .\targets.xml -WhatIf

        Description:
        Reads targets.xml that defines a list of files and folders to delete from the user profile.
        Reports on the files/folders to delete without deleting them.

    .EXAMPLE
    C:\> .\$($MyInvocation.MyCommand).ps1 -Targets .\targets.xml -Confirm:$False -Verbose

        Description:
        Reads targets.xml that defines a list of files and folders to delete from the user profile.
        Deletes the targets and reports on the total size of files removed.

    .INPUTS
    XML file that defines target files and folders to remove.

    .OUTPUTS
        [System.String]

    .NOTES
        Windows profiles can be cleaned up to reduce profile size and bloat.
        Use with traditional profile solutions to clean up profiles or with Container-based solution to keep Container sizes to minimum.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', `
        HelpUri = 'https://github.com/aaronparker/FSLogix/blob/master/Profile-Cleanup/README.MD')]
[OutputType([System.String])]
Param (
    [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript( { If (Test-Path $_ -PathType 'Leaf') { $True } Else { Throw "Cannot find file $_" } })]
    [Alias("Path", "Xml")]
    [System.String] $Targets,

    [Parameter(Mandatory = $False, Position = 1)]
    [ValidateScript( { If (Test-Path (Split-Path $_ -Parent) -PathType 'Container') { $True } Else { Throw "Cannot find log file directory." } })]
    [System.String] $LogFile = $(Join-Path (Resolve-Path $PWD) $("Profile-" + $((Get-Date).ToFileTimeUtc()) + ".log")),

    [Parameter(Mandatory = $False)]
    [System.Management.Automation.SwitchParameter] $Override
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

# Output array, will contain the list of files/folders removed
$fileList = New-Object -TypeName System.Collections.ArrayList

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
Write-Verbose -Message "Writing file list to $LogFile."

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
        ForEach ($path in $target.Node.Path) {
            
            # Convert path from XML with environment variable to actual path
            $thisPath = $(ConvertTo-Path -Path $path.innerText)
            Write-Verbose -Message "Processing folder: $thisPath"

            # Get files to delete from Paths and file age; build output array
            If (Test-Path -Path $(Get-TestPath -Path $thisPath) -ErrorAction SilentlyContinue) {

                Switch ($path.Action) {
                    "Prune" {
                        # Get file age from Days value in XML; if -Override used, set $dateFilter to now
                        If ($Override) {
                            $dateFilter = Get-Date
                        }
                        Else {
                            $dateFilter = (Get-Date).AddDays(- $path.Days)
                        }

                        # Construct the file list for this folder and add to the full list for logging
                        $files = Get-ChildItem -Path $thisPath -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -le $dateFilter }
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
                        Write-Warning -Message "[Unable to determine action for $thisPath]"
                    }
                }
            }
        }
    }
}

# Output total size of files deleted
If ($fileList.Count -gt 1) {
    $size = ($fileList | Measure-Object -Sum Length).Sum
    $size = Convert-Size -From B -To MiB -Value $size
}
Else {
    $size = 0
}
Write-Verbose -Message "Total file size deleted: $size MiB"

# Write deleted file list out to the log file
If ($WhatIfPreference -eq $True) { $WhatIfPreference = $False }
"[$($MyInvocation.MyCommand)][$(Get-Date -Format FileDateTime)] File list start" | Out-File -FilePath $LogFile -Append
$fileList.FullName | Out-File -FilePath $LogFile -Append
"[$($MyInvocation.MyCommand)][$(Get-Date -Format FileDateTime)] File list end" | Out-File -FilePath $LogFile -Append

# Stop time recording
$stopWatch.Stop()
"[$($MyInvocation.MyCommand)][$(Get-Date -Format FileDateTime)] Time to complete $($stopWatch.Elapsed.TotalMilliseconds) ms" | Out-File -FilePath $LogFile -Append
"[$($MyInvocation.MyCommand)][$(Get-Date -Format FileDateTime)] Total file size deleted $size MiB" | Out-File -FilePath $LogFile -Append
Write-Verbose -Message "Script took $($stopWatch.Elapsed.TotalMilliseconds) ms to complete."

# Return the size of the deleted files in MiB to the pipeline
Write-Output -InputObject "Deleted: $size MiB"
