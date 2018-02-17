<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
.INPUTS
   Inputs to this cmdlet (if any)
.OUTPUTS
   Output from this cmdlet (if any)
.NOTES
   General notes
.COMPONENT
   The component this cmdlet belongs to
.ROLE
   The role this cmdlet belongs to
.FUNCTIONALITY
   The functionality that best describes this cmdlet
#>
[CmdletBinding(DefaultParameterSetName = 'Default', SupportsShouldProcess = $true, 
    PositionalBinding = $false, HelpUri = 'https://stealthpuppy.com/', ConfirmImpact = 'High')]
[OutputType([String])]
Param (
    # Param1 help description
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, 
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
}
Process {
    # Read the specifed XML document
    Try { [xml]$xmlDocument = Get-Content -Path $Xml -ErrorVariable xmlReadError }
    Catch { Throw "Unable to read: $Xml. $xmlReadError" }

    # Select each Target XPath
    $Targets = Select-Xml -Xml $xmlDocument -XPath "//Target"

    $Output = @()

    # Walk through each target to delete files
    ForEach ($Target in $Targets) {
        Write-Verbose "Processing target: [$($Target.Node.Name)]"
        ForEach ($Path in $Target.Node.Path) {
            Write-Verbose "Processing folder: $(ConvertTo-Path -Path $Path.innerText)"

            # Get file age from Days value in XML
            $DateFilter = (Get-Date).AddDays( - $Path.Days)

            # Get files to delete from Paths and file age
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