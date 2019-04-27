#Requires -Version 3
<#
    .SYNOPSIS
        Converts an input CSV file into an FSLogix Redirections.xml

    .DESCRIPTION
        
    .NOTES
        Author: Aaron Parker
        Twitter: @stealthpuppy

    .LINK
        https://stealthpuppy.com
#>
[CmdletBinding()]
Param (
    [Parameter()]
    [string] $Redirections = "https://raw.githubusercontent.com/aaronparker/FSLogix/master/Redirections/Redirections.csv"
)

# Read the file and convert from CSV
$Paths = (Invoke-WebRequest -Uri $Redirections -UseBasicParsing).Content

# Create the XML document
[xml] $Doc = New-Object System.Xml.XmlDocument
$declaration = $Doc.CreateXmlDeclaration("1.0","UTF-8",$null)
$doc.AppendChild($declaration)

ForEach ($path in $Paths) {

}

<#
<?xml version="1.0" encoding="UTF-8"?>
<FrxProfileFolderRedirection ExcludeCommonFolders="0">
    <Excludes>
        <Exclude Copy="###VALUE###">AppData\Low\FolderToDiscard</Exclude>
        <Exclude>… another exclude folders… </Exclude>
    </Excludes>
    <Includes>
        <Include>AppData\Low\FolderToDiscard\FolderToKeep</Include>
        <Include>… another include folders… </Include>
    </Includes>
</FrxProfileFolderRedirection>
#>