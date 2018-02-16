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
    [ValidateScript({ If (Test-Path $_ -PathType 'Leaf') { $True } Else { Throw "Cannot find file $_" } })]
    [Alias("Path")]
    [string[]]$Xml
)
Begin {
}
Process {
    If ($pscmdlet.ShouldProcess("Target", "Operation")) {
    }

    # Read the specifed XML document
    Try { [xml]$xmlDocument = Get-Content -Path $Xml -ErrorVariable xmlReadError }
    Catch { Throw "Unable to read: $Xml. $xmlReadError" }

    # Select Paths
    Select-Xml -Xml $xmlDocument -XPath "//Target/Path" | ForEach-Object {$_.node.InnerXML}
    Select-Xml -Xml $xmlDocument -XPath "//Target/Path" | Select-Object -ExpandProperty Days
}
End {
}