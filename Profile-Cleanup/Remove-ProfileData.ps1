<#
.Synopsis
   Removes files and folders in the user profile to reduce profile size.

.DESCRIPTION
   Reads a list of files and folders from an XML file to delete data based on age.
   The script reads an XML file that defines a list of files and folders to remove to reduce profile size.
   Supports -WhatIf and -Verbose output and returns a list of files removed from the profile.

.EXAMPLE
   .\Remove-ProfileData.ps1 -Xml .\targets.xml

.INPUTS
   XML file that defines target files and folders to remove.

.OUTPUTS
   System.Array

.NOTES
   Windows profiles can be cleaned up to reduce profile size and bloat.
   Use with traditional profile solutions to clean up profiles or with Container-based solution to keep Container sizes to minimum.

.FUNCTIONALITY

#>
[CmdletBinding(DefaultParameterSetName = 'Default', SupportsShouldProcess = $true, 
    PositionalBinding = $false, HelpUri = 'https://stealthpuppy.com/', ConfirmImpact = 'High')]
[OutputType([String])]
Param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, 
        ValueFromRemainingArguments = $false, Position = 0, ParameterSetName = 'Default')]
    [ValidateNotNullOrEmpty()]
    [ValidateScript( { If (Test-Path $_ -PathType 'Leaf') { $True } Else { Throw "Cannot find file $_" } })]
    [Alias("Path")]
    [string[]]$Xml
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
            { $_ -match "%LocalAppData%" } { $Path = $Path -replace "%LocalAppData%", $env:LocalAppData }
            { $_ -match "%AppData%" } { $Path = $Path -replace "%AppData%", $env:AppData }
            { $_ -match "%TEMP%" } { $Path = $Path -replace "%TEMP%", $env:Temp }
        }
        $Path
    }

    # Output array, will contain the list of files/folders removed
    $Output = @()
}
Process {
    # Read the specifed XML document
    Try { [xml]$xmlDocument = Get-Content -Path $Xml -ErrorVariable xmlReadError }
    Catch { Throw "Unable to read: $Xml. $xmlReadError" }

    # Select each Target XPath
    $Targets = Select-Xml -Xml $xmlDocument -XPath "//Target"

    # Walk through each target to delete files
    ForEach ($Target in $Targets) {
        Write-Verbose "Processing target: [$($Target.Node.Name)]"
        ForEach ($Path in $Target.Node.Path) {
            Write-Verbose "Processing folder: $(ConvertTo-Path -Path $Path.innerText)"

            # Get file age from Days value in XML
            $DateFilter = (Get-Date).AddDays( - $Path.Days)

            # Get files to delete from Paths and file age; build output array
            $Files = Get-ChildItem -Path $(ConvertTo-Path -Path $Path.innerText) -Include *.* -Recurse -Force -ErrorAction SilentlyContinue `
                | Where-Object { $_.PSIsContainer -eq $False -and $_.LastWriteTime -le $DateFilter }
            $Output += $Files

            # Delete files with support for -WhatIf
            ForEach ( $File in $Files ) {
                If ($pscmdlet.ShouldProcess($File, "Delete")) {
                    Remove-Item -Path $File -Force
                }
            }
        }
    }
}
End {
    # Return the files array (e.g. output for logging)
    Write-Output $Output
}