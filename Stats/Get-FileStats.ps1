#Requires -Version 2
<#
    .SYNOPSIS
        Gets file stats and owner from a specified path.
    
    .DESCRIPTION
        Retrieves the file stats (with Size, Last Write Time, Last Modified Time) and Owner from files in a specified path. Outputs sizes in MiB, by default.

    .NOTES
        Author: Aaron Parker
        Twitter: @stealthpuppy
        
    .LINK
        https://stealthpuppy.com

    .INPUTS
        System.String[]
            You can pipe a file system path (in quotation marks) to Get-FileStats
    
    .OUTPUTS
        System.Array

    .PARAMETER Path
        Specified a path to one or more location which to scan files.

    .EXAMPLE
        .\Get-FileStats.ps1 -Path "\\server\share\folder"

        Description:
        Scans the specified path returns the age and owner for each file.

    .PARAMETER Include
        Gets only the specified items.

    .EXAMPLE
        .\Get-FileStats.ps1 -Path "\\server\share\folder" -Include ".vhdx"

        Description:
        Scans the specified path returns the age and owner for each .vhdx file.
#>
[CmdletBinding(HelpUri = 'https://github.com/aaronparker/fslogix/Stats/README.MD')]
[OutputType([System.Array])]
Param (
    [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, `
            HelpMessage = 'Specify a target path, paths or a list of files to scan for stats.')]
    [Alias('FullName', 'PSPath')]
    [System.String[]] $Path, 

    [Parameter(Mandatory = $False, Position = 1, HelpMessage = 'Gets only the specified items.')]
    [Alias('Filter')]
    [System.String[]] $Include = "*.vhdx"
)
Begin {
    #region Functions
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
    #endregion

    Write-Verbose -Message "Beginning file stats trawling."
    $fileList = New-Object -TypeName "System.Collections.ArrayList"
}
Process {
    ForEach ($folder in $Path) {

        # For each path in $folder, check that the path exists
        If (Test-Path -Path $folder) {

            # Get the item to determine whether it's a file or folder
            If ((Get-Item -Path $folder).PSIsContainer) {

                # Target is a folder, so trawl the folder for files in the target and sub-folders
                Write-Verbose -Message "Getting stats for files in folder: $folder"
                try {
                    $items = Get-ChildItem -Path $folder -Recurse -File -Include $Include -Force -ErrorAction SilentlyContinue
                }
                catch [System.Exception] {
                    Write-Warning -Message "`Get-ChildItem -Recurse` failed on $folder."
                    Throw $_.Exception.Message
                }
            }
            Else {
                # Target is a file, so just get metadata for the file
                Write-Verbose -Message "Getting stats for file: $folder"
                try {
                    $items = Get-ChildItem -Path $folder -ErrorAction SilentlyContinue
                }
                catch [System.Exception] {
                    Write-Warning -Message "`Get-ChildItem -Recurse` failed on $folder."
                    Throw $_.Exception.Message
                }
            }

            # Create an array from what was returned for specific data and sort on file path
            If ($Null -ne $items) {
                $files = $items | Select-Object @{Name = "Location"; Expression = { $_.Directory } }, `
                @{Name = "Name"; Expression = { $_.Name } }, 
                @{Name = "Owner"; Expression = { (Get-Acl -Path $_.FullName).Owner } }, `
                @{Name = "Size"; Expression = { "$(Convert-Size -From B -To MiB -Value $_.Length) MiB" } }, `
                @{Name = "LastWriteTime"; Expression = { $_.LastWriteTime } }, `
                @{Name = "LastAccessTime"; Expression = { $_.LastAccessTime } }
                $fileList.Add($files) | Out-Null
            }
        }
        Else {
            Write-Warning -Message "Path does not exist: $folder"
        }
    }
}
End {
    # Return the array of file paths and metadata    
    $sortedFiles = $fileList | Sort-Object -Property @{Expression = "LastWriteTime"; Descending = $True }, @{Expression = "Name"; Descending = $False }
    Write-Output -InputObject $sortedFiles
}
