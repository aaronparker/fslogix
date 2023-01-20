<#PSScriptInfo

.VERSION 1.0.9

.GUID 118b1874-d4b2-45bc-a698-f91f9568416c

.AUTHOR Aaron Parker

.COMPANYNAME stealthpuppy

.COPYRIGHT 2023, Aaron Parker. All rights reserved.

.TAGS FSLogix Profile-Containers Profile

.LICENSEURI https://github.com/aaronparker/fslogix/blob/main/LICENSE

.PROJECTURI https://github.com/aaronparker/fslogix/tree/main/Redirections

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
- 1.0.1, Initial version, April 2019
- 1.0.2, Support local Redirections.csv as input
- 1.0.3, Convert-CsvContent function, code cleanup
- 1.0.4, Additional error checking
- 1.0.5, Run Update-ScriptFileInfo on script to fix issues on Windows Server 2012/R2
- 1.0.6, Update to include Notes as comments in the XML; Minor code updates
- 1.0.7, Update default $Redirections value due to changes in repository path
- 1.0.8, Update references to repo name, help URL
- 1.0.9, Code and tests clean-up

.PRIVATEDATA

#>
 
<#
    .SYNOPSIS
        Converts a correctly formatted input CSV file into an FSLogix Redirections.xml for use with Profile Container.

    .DESCRIPTION
        Converts a correctly formatted input CSV file into an FSLogix Redirections.xml for use with FSLogix Profile Containers. Downloads the redirections data from the source repo hosted on GitHub and converts the input CSV file into an FSLogix Redirections.xml.

    .PARAMETER Redirections
        The URI to the Redirections.csv hosted in the FSLogix repo.

    .PARAMETER OutFile
        A local file to save the output to. The default output file will be Redirections.xml in the curent directory.
        
    .NOTES
        Author: Aaron Parker
        Twitter: @stealthpuppy

    .LINK
        https://stealthpuppy.com/fslogix/redirectionsxml/

    .EXAMPLE
        ConvertTo-RedirectionsXml.ps1

        Output Redirections.xml to the current directory.

    .EXAMPLE
        ConvertTo-RedirectionsXml.ps1 -OutFile C:\Temp\Redirections.xml

        Output Redirections.xml to the C:\Temp\Redirections.xml.
#>
[CmdletBinding(SupportsShouldProcess = $True, HelpURI = "https://stealthpuppy.com/fslogix/redirectionsxml/")]
[OutputType([System.String])]
param (
    [Parameter(Mandatory = $false)]
    [System.String] $Redirections = "https://raw.githubusercontent.com/aaronparker/fslogix/main/Redirections/Redirections.csv",

    [Parameter(Mandatory = $false)]
    [System.String] $OutFile = "Redirections.xml"
)

#region Functions
function Convert-CsvContent {
    [OutputType([System.Management.Automation.PSObject])]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline)]
        [System.String] $Content
    )
    try {
        $convertedContent = $Content | ConvertFrom-Csv -ErrorAction "Stop"
        Write-Output -InputObject $convertedContent
    }
    catch [System.Exception] {
        Write-Warning -Message "$($MyInvocation.MyCommand): Failed to convert content."
        throw $_.Exception.Message
    }
}

function Get-WebRequest {
    [OutputType([System.Management.Automation.PSObject])]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline)]
        [System.String] $Uri
    )
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $params = @{
            Uri             = $Uri
            UseBasicParsing = $True
            ErrorAction     = "SilentlyContinue"
        }
        $content = Invoke-WebRequest @params
        Write-Output -InputObject $content.Content
    }
    catch [System.Exception] {
        throw $_
    }
}

function Get-FileContent {
    [OutputType([System.Management.Automation.PSObject])]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline)]
        [ValidateScript( { if (Test-Path -Path $_ -PathType 'Leaf') { $true } else { throw "$($MyInvocation.MyCommand): cannot find file $_" } })]
        [System.String] $Path
    )
    $Path = Resolve-Path -Path $Path
    try {
        $params = @{
            Path        = $Path
            Raw         = $True
            ErrorAction = "SilentlyContinue"
        }
        $content = Get-Content @params
        Write-Output -InputObject $content
    }
    catch [System.Exception] {
        throw $_
    }
}
#endregion

# Read the file and convert from CSV. Support https or local file source
if ($Redirections -match "http.*://") {
    $content = Get-WebRequest -Uri $Redirections
}
else {
    $content = Get-FileContent -Path (Resolve-Path -Path $Redirections)
}

# Convert the content from CSV format
$Paths = Convert-CsvContent -Content $Content

# Convert
if ($null -eq $Paths) {
    Write-Warning -Message "$($MyInvocation.MyCommand): List of redirection paths is null."
}
else {
    # Strings
    $xmlVersion = "1.0"
    $xmlEncoding = "UTF-8"
    $xmlComment = "Generated $(Get-Date -Format yyyy-MM-dd) from $Redirections"
    $xmlRootNode = "FrxProfileFolderRedirection"
    $xmlRootNodeAttribute1 = "ExcludeCommonFolders"
    $xmlRootNodeAttribute1Value = "0"
    $xmlExcludeNode = "Excludes"
    $xmlExcludeNodeElement = "Exclude"
    $xmlIncludeNode = "Includes"
    $xmlIncludeNodeElement = "Include"
    $xmlNodeAttribute1 = "Copy"

    # Create the XML document
    [xml] $xmlDoc = New-Object -TypeName System.Xml.XmlDocument
    $declaration = $xmlDoc.CreateXmlDeclaration($xmlVersion, $xmlEncoding, $null)
    $xmlDoc.AppendChild($declaration) | Out-Null

    # Add a comment with generation details
    $xmlDoc.AppendChild($xmlDoc.CreateComment($xmlComment)) | Out-Null

    # Create the FrxProfileFolderRedirection root node
    $root = $xmlDoc.CreateNode("element", $xmlRootNode, $null)
    $root.SetAttribute($xmlRootNodeAttribute1, $xmlRootNodeAttribute1Value)

    # Create the Excludes child node of FrxProfileFolderRedirection
    $excludes = $xmlDoc.CreateNode("element", $xmlExcludeNode, $null)
    foreach ($path in ($Paths | Where-Object { $_.Action -eq $xmlExcludeNodeElement })) {
        $node = $xmlDoc.CreateElement($xmlExcludeNodeElement)
        $node.SetAttribute($xmlNodeAttribute1, $path.Copy)
        $node.InnerText = $path.Path
        $excludes.AppendChild($xmlDoc.CreateComment($path.Notes)) | Out-Null
        $excludes.AppendChild($node) | Out-Null
    }
    $root.AppendChild($excludes) | Out-Null

    # Create the Includes child node of FrxProfileFolderRedirection
    $includes = $xmlDoc.CreateNode("element", $xmlIncludeNode, $null)
    foreach ($path in ($Paths | Where-Object { $_.Action -eq $xmlIncludeNodeElement })) {
        $node = $xmlDoc.CreateElement($xmlIncludeNodeElement)
        $node.SetAttribute($xmlNodeAttribute1, $path.Copy)
        $node.InnerText = $path.Path
        $includes.AppendChild($node) | Out-Null
    }
    $root.AppendChild($includes) | Out-Null

    # Append the FrxProfileFolderRedirection root node to the XML document
    $xmlDoc.AppendChild($root) | Out-Null

    # Check supplied output path and resolve full path
    $Parent = Split-Path -Path $OutFile -Parent
    if ($Parent.Length -eq 0) {
        $Parent = $PWD
    }
    else {
        $Parent = Resolve-Path -Path $Parent
    }
    $outputFilePath = Join-Path -Path $Parent -ChildPath (Split-Path -Path $OutFile -Leaf)

    # Save to an XML file
    try {
        $xmlDoc.Save($outputFilePath)
    }
    catch [System.Exception] {
        throw $_
    }

    # Write the output file path to the pipeline
    if ($null -ne $outputFilePath) {
        Write-Output -InputObject (Get-ChildItem -Path $outputFilePath)
    }
}
