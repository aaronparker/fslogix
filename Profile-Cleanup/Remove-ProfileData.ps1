#Requires -Version 2
<#
    .SYNOPSIS
    Removes files and folders in the user profile to reduce profile size.

    .DESCRIPTION
    Reads a list of files and folders from an XML file to delete data based on age.
    The script reads an XML file that defines a list of files and folders to remove to reduce profile size.
    Supports -WhatIf and -Verbose output and returns a list of files removed from the profile.

    .PARAMETER Xml
        Path to an XML file that defines the profile paths to prune and delete

    .PARAMETER Override
        Override the days value listed for each path in the XML file resulting in forced removal of all files in the path.

    .PARAMETER LogFile
        Path to file for logging all files that are removed.

    .EXAMPLE
    .\Remove-ProfileData.ps1 -Xml .\targets.xml -WhatIf

        Description:
        Reads targets.xml that defines a list of files and folders to delete from the user profile.
        Reports on the files/folders to delete without deleting them.

    .EXAMPLE
    $files = .\Remove-ProfileData.ps1 -Xml .\targets.xml -Confirm:$False -Verbose

        Description:
        Reads targets.xml that defines a list of files and folders to delete from the user profile.
        Deletes the targets and returns the list of files into $files. Also reports on the total size of files removed.

    .INPUTS
    XML file that defines target files and folders to remove.

    .OUTPUTS
    System.String

    .NOTES
    Windows profiles can be cleaned up to reduce profile size and bloat.
    Use with traditional profile solutions to clean up profiles or with Container-based solution to keep Container sizes to minimum.

    .FUNCTIONALITY

#>
[CmdletBinding(SupportsShouldProcess = $true, PositionalBinding = $false, `
        HelpUri = 'https://stealthpuppy.com/', ConfirmImpact = 'High')]
[OutputType([String])]
Param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript( { If (Test-Path $_ -PathType 'Leaf') { $True } Else { Throw "Cannot find file $_" } })]
    [Alias("Path")]
    [string[]] $Xml,

    [Parameter(Mandatory = $false)]
    [ValidateScript( { If (Test-Path (Split-Path $LogFile -Parent) -PathType 'Container') { $True } Else { Throw "Cannot find log file directory." } })]
    [string] $LogFile = $(Join-Path (Resolve-Path ".\") $("Remove-ProfileData-" + $((Get-Date).ToFileTimeUtc()) + ".log")),

    [Parameter(Mandatory = $false)]
    [switch] $Override
)

Begin {
    Function ConvertTo-Path {
        <#
          .SYNOPSIS
            Replaces environment variables in strings with actual path
        #>
        Param (
            [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True)]
            [string]$Path
        )
        Switch ($Path) {
            { $_ -match "%USERPROFILE%" } { $Path = $Path -replace "%USERPROFILE%", $env:USERPROFILE }
            { $_ -match "%LocalAppData%" } { $Path = $Path -replace "%LocalAppData%", $env:LocalAppData }
            { $_ -match "%AppData%" } { $Path = $Path -replace "%AppData%", $env:AppData }
            { $_ -match "%TEMP%" } { $Path = $Path -replace "%TEMP%", $env:Temp }
        }
        $Path
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
        [cmdletbinding()]
        param(
            [ValidateSet("b", "B", "KB", "KiB", "MB", "MiB", "GB", "GiB", "TB", "TiB", "PB", "PiB", "EB", "EiB", "ZB", "ZiB", "YB", "YiB")]
            [Parameter(Mandatory = $true)]
            [string] $From,
            
            [ValidateSet("b", "B", "KB", "KiB", "MB", "MiB", "GB", "GiB", "TB", "TiB", "PB", "PiB", "EB", "EiB", "ZB", "ZiB", "YB", "YiB")]
            [Parameter(Mandatory = $true)]
            [string] $To,
            
            [Parameter(Mandatory = $true)]
            [double] $Value,

            [int]$Precision = 2
        )
        # Convert the supplied value to Bytes
        switch -casesensitive ($From) {
            "b" {$value = $value / 8 }
            "B" {$value = $Value }
            "KB" {$value = $Value * 1000 }
            "KiB" {$value = $value * 1024 }
            "MB" {$value = $Value * 1000000 }
            "MiB" {$value = $value * 1048576 }
            "GB" {$value = $Value * 1000000000 }
            "GiB" {$value = $value * 1073741824 }
            "TB" {$value = $Value * 1000000000000 }
            "TiB" {$value = $value * 1099511627776 }
            "PB" {$value = $value * 1000000000000000 }
            "PiB" {$value = $value * 1125899906842624 }
            "EB" {$value = $value * 1000000000000000000 }
            "EiB" {$value = $value * 1152921504606850000 }
            "ZB" {$value = $value * 1000000000000000000000 }
            "ZiB" {$value = $value * 1180591620717410000000 }
            "YB" {$value = $value * 1000000000000000000000000 }
            "YiB" {$value = $value * 1208925819614630000000000 }
        }
        # Convert the number of Bytes to the desired output
        switch -casesensitive ($To) {
            "b" {$value = $value * 8}
            "B" {return $value }
            "KB" {$Value = $Value / 1000 }
            "KiB" {$value = $value / 1024 }
            "MB" {$Value = $Value / 1000000 }
            "MiB" {$Value = $Value / 1048576 }
            "GB" {$Value = $Value / 1000000000 }
            "GiB" {$Value = $Value / 1073741824 }
            "TB" {$Value = $Value / 1000000000000 }
            "TiB" {$Value = $Value / 1099511627776 }
            "PB" {$Value = $Value / 1000000000000000 }
            "PiB" {$Value = $Value / 1125899906842624 }
            "EB" {$Value = $Value / 1000000000000000000 }
            "EiB" {$Value = $Value / 1152921504606850000 }
            "ZB" {$value = $value / 1000000000000000000000 }
            "ZiB" {$value = $value / 1180591620717410000000 }
            "YB" {$value = $value / 1000000000000000000000000 }
            "YiB" {$value = $value / 1208925819614630000000000 }
        }
        [Math]::Round($value, $Precision, [MidPointRounding]::AwayFromZero)
    }

    Function Remove-ExceptLatest {
        <#
          .SYNOPSIS
            Remove all sub-folders except the most recent folder
        #>
        Param (
            [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True)]
            [string] $Path
        )
        $Latest = Get-ChildItem -Path $Path | Sort-Object -Descending | Select-Object -First 1
        Get-ChildItem -Path $Path -Exclude $Latest | Remove-Item -Recurse -Force
    }

    Function Get-TestPath {
        <#
          .SYNOPSIS
            Check whether path includes wildcards in file names
            If so, return parent path, or just return the same path
        #>
        Param (
            [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True)]
            [string] $Path
        )
        If ((Split-Path -Path $Path -Leaf) -match "[*?]") {
            $fileList = Split-Path -Path $Path -Parent
        }
        Else {
            $fileList = $Path
        }
        Write-Output $fileList
    }

    # Output array, will contain the list of files/folders removed
    $fileList = @()

    # Measure time taken to gather data
    $stopWatch = [system.diagnostics.stopwatch]::StartNew()
    "[Remove-ProfileData]" | Out-File -FilePath $LogFile -Append
    Write-Warning "Writing file list to $LogFile."
}

Process {
    # Read the specifed XML document
    Try {
        [xml] $xmlDocument = Get-Content -Path $Xml -ErrorVariable xmlReadError -ErrorAction SilentlyContinue
    }
    Catch {
        Throw "Unable to read: $Xml. $xmlReadError"
        Break
    }

    # Select each Target XPath; walk through each target to delete files
    ForEach ($target in (Select-Xml -Xml $xmlDocument -XPath "//Target")) {
        Write-Verbose "Processing target: [$($target.Node.Name)]"
        ForEach ($path in $target.Node.Path) {
            
            # Convert path from XML with environment variable to actual path
            $thisPath = $(ConvertTo-Path -Path $path.innerText)
            Write-Verbose "Processing folder: $thisPath"

            # Get file age from Days value in XML; if -Override used, set $dateFilter to now
            If ($Override) {
                $dateFilter = Get-Date
            }
            Else {
                $dateFilter = (Get-Date).AddDays( - $Path.Days)
            }

            # Get files to delete from Paths and file age; build output array
            If (Test-Path -Path $(Get-TestPath -Path $ThisPath) -ErrorAction SilentlyContinue) {

                # Construct the file list for this folder and add to the full list for logging
                $files = Get-ChildItem -Path $ThisPath -Recurse -Force -ErrorAction SilentlyContinue `
                    | Where-Object { $_.LastWriteTime -le $dateFilter }
                $fileList += $files

                # Delete files with support for -WhatIf
                ForEach ($file in $files) {
                    If (Test-Path -Path $file.FullName -ErrorAction SilentlyContinue) {
                        If ($pscmdlet.ShouldProcess($file.FullName, "Delete")) {
                            Remove-Item -Path $file.FullName -Force -Recurse -ErrorAction SilentlyContinue
                        }
                    }
                    ElseIf ($Error[0].Exception -is [System.UnauthorizedAccessException]) {
                        Write-Verbose "[UnauthorizedAccessException] accessing $($file.FullName)"
                    }
                }
            }
        }
    }
}

End {
    # Output total size of files deleted
    $size = ($fileList | Measure-Object -Sum Length).Sum
    Write-Verbose "Total file size deleted: $(Convert-Size -From B -To MiB -Value $size) MiB"

    # Stop time recording
    $stopWatch.Stop()
    Write-Verbose "Script took $($stopWatch.Elapsed.TotalMilliseconds) ms to complete."
    
    # Write deleted file list out to the log file
    ($fileList | Select-Object FullName).FullName | Out-File -FilePath $LogFile -Append
    "[Remove-ProfileData: Time to complete $($stopWatch.Elapsed.TotalMilliseconds) ms]" | Out-File -FilePath $LogFile -Append
    "[Remove-ProfileData: Total file size deleted $(Convert-Size -From B -To MiB -Value $size) MiB]" | Out-File -FilePath $LogFile -Append

    # Return the size of the deleted files in MiB to the pipeline
    Write-Output (Convert-Size -From B -To MiB -Value $size)
}
