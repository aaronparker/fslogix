# Requires -Version 2
<#
.SYNOPSIS
   Removes files and folders in the user profile to reduce profile size.

.DESCRIPTION
   Reads a list of files and folders from an XML file to delete data based on age.
   The script reads an XML file that defines a list of files and folders to remove to reduce profile size.
   Supports -WhatIf and -Verbose output and returns a list of files removed from the profile.

.EXAMPLE
   .\Remove-ProfileData.ps1 -Xml .\targets.xml -WhatIf

    Description:
    Reads targets.xml that defines a list of files and folders to delete from the user profile.
    Reports on the files/folders to delete without deleting them.

.EXAMPLE
   $Files = .\Remove-ProfileData.ps1 -Xml .\targets.xml -Confirm:$False -Verbose

    Description:
    Reads targets.xml that defines a list of files and folders to delete from the user profile.
    Deletes the targets and returns the list of files into $Files. Also reports on the total size of files removed.

.INPUTS
   XML file that defines target files and folders to remove.

.OUTPUTS
   System.Array

.NOTES
   Windows profiles can be cleaned up to reduce profile size and bloat.
   Use with traditional profile solutions to clean up profiles or with Container-based solution to keep Container sizes to minimum.

.FUNCTIONALITY

#>
[CmdletBinding(SupportsShouldProcess = $true, PositionalBinding = $false, `
HelpUri = 'https://stealthpuppy.com/', ConfirmImpact = 'High')]
[OutputType([String])]
Param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, 
        ValueFromRemainingArguments = $false, Position = 0, ParameterSetName = 'Default')]
    [ValidateNotNullOrEmpty()]
    [ValidateScript( { If (Test-Path $_ -PathType 'Leaf') { $True } Else { Throw "Cannot find file $_" } })]
    [Alias("Path")]
    [string[]]$Xml,

    [Parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false,
        ValueFromRemainingArguments = $false, ParameterSetName = 'Default')]
    [switch]$Override
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
            [validateset("b", "B", "KB", "KiB", "MB", "MiB", "GB", "GiB", "TB", "TiB", "PB", "PiB", "EB", "EiB", "ZB", "ZiB", "YB", "YiB")]
            [Parameter(Mandatory = $true)]
            [string]$From,
            [validateset("b", "B", "KB", "KiB", "MB", "MiB", "GB", "GiB", "TB", "TiB", "PB", "PiB", "EB", "EiB", "ZB", "ZiB", "YB", "YiB")]
            [Parameter(Mandatory = $true)]
            [string]$To,
            [Parameter(Mandatory = $true)]
            [double]$Value,
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
            [string]$Path
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
            [string]$Path
        )
        If ((Split-Path -Path $Path -Leaf) -match "[*?]") {
            $Output = Split-Path -Path $Path -Parent
        }
        Else {
            $Output = $Path
        }
        $Output
    }

    # Output array, will contain the list of files/folders removed
    $Output = @()

    # Measure time taken to gather data
    $StopWatch = [system.diagnostics.stopwatch]::StartNew()
}
Process {
    # Read the specifed XML document
    Try { [xml]$xmlDocument = Get-Content -Path $Xml -ErrorVariable xmlReadError }
    Catch { Throw "Unable to read: $Xml. $xmlReadError" }

    # Select each Target XPath; walk through each target to delete files
    ForEach ($Target in (Select-Xml -Xml $xmlDocument -XPath "//Target")) {
        Write-Verbose "Processing target: [$($Target.Node.Name)]"
        ForEach ($Path in $Target.Node.Path) {
            
            # Convert path from XML with environment variable to actual path
            $ThisPath = $(ConvertTo-Path -Path $Path.innerText)
            Write-Verbose "Processing folder: $ThisPath"

            # Get file age from Days value in XML; if -Override used, set $DateFilter to now
            If ($Override) { $DateFilter = Get-Date } Else { $DateFilter = (Get-Date).AddDays( - $Path.Days) }

            # Get files to delete from Paths and file age; build output array
            If (Test-Path -Path $(Get-TestPath -Path $ThisPath) -ErrorAction SilentlyContinue) {

                $Files = Get-ChildItem -Path $ThisPath -Recurse -Force -ErrorAction SilentlyContinue `
                    | Where-Object { $_.LastWriteTime -le $DateFilter }
                $Output += $Files

                # Delete files with support for -WhatIf
                ForEach ( $File in $Files ) {
                    If (Test-Path -Path $File.FullName -ErrorAction SilentlyContinue) {
                        If ($pscmdlet.ShouldProcess($File.FullName, "Delete")) {
                            Remove-Item -Path $File.FullName -Force -Recurse -ErrorAction SilentlyContinue
                        }
                    }
                    ElseIf ( $Error[0].Exception -is [System.UnauthorizedAccessException] ) {
                        Write-Verbose "[UnauthorizedAccessException] accessing $($File.FullName)"
                    }
                }
            }
        }
    }
}
End {
    # Output total size of files deleted
    $Size = ($Output | Measure-Object -Sum Length).Sum
    Write-Verbose "Total file size deleted: $(Convert-Size -From B -To MiB -Value $Size) MiB"

    $StopWatch.Stop()
    Write-Verbose "Script took $($StopWatch.Elapsed.TotalMilliseconds) ms to complete."
    
    # Return the files array (e.g. output for logging)
    Write-Output $Output
}