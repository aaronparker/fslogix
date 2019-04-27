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
    [Parameter(Mandatory = $false)]
    [string] $Redirections = "https://raw.githubusercontent.com/aaronparker/FSLogix/master/Redirections/Redirections.csv",

    [Parameter(Mandatory = $false)]
    [string] $OutFile = "Redirections.xml"
)

# Read the file and convert from CSV
$Paths = (Invoke-WebRequest -Uri $Redirections -UseBasicParsing).Content | ConvertFrom-Csv

# Create the XML document
[xml] $xmlDoc = New-Object System.Xml.XmlDocument
$declaration = $xmlDoc.CreateXmlDeclaration("1.0", "UTF-8", $Null)
$xmlDoc.AppendChild($declaration)

# Add a comment with generation details
$comment = "Generated $(Get-Date -Format yyyy-MM-dd) from $Redirections"
$xmlDoc.AppendChild($xmlDoc.CreateComment($comment))

# Create the FrxProfileFolderRedirection root node
$root = $xmlDoc.CreateNode("element", "FrxProfileFolderRedirection", $Null)
$root.SetAttribute("ExcludeCommonFolders", "0")

# Create the Excludes child node of FrxProfileFolderRedirection
$excludes = $xmlDoc.CreateNode("element", "Excludes", $Null)
ForEach ($path in ($Paths | Where-Object { $_.Action -eq "Exclude" })) {
    $node = $xmlDoc.CreateElement("Exclude")
    $node.SetAttribute("Copy", $path.Copy)
    $node.InnerText = $path.Path
    $excludes.AppendChild($node)
}
$root.AppendChild($excludes)

# Create the Includes child node of FrxProfileFolderRedirection
$includes = $xmlDoc.CreateNode("element", "Includes", $Null)
ForEach ($path in ($Paths | Where-Object { $_.Action -eq "Include" })) {
    $node = $xmlDoc.CreateElement("Include")
    $node.SetAttribute("Copy", $path.Copy)
    $node.InnerText = $path.Path
    $includes.AppendChild($node)
}
$root.AppendChild($includes)

# Append the FrxProfileFolderRedirection root node to the XML document
$xmlDoc.AppendChild($root)

# Check path and output to an XML file
$Parent = Split-Path -Path $OutFile -Parent
If ($Parent.Length -eq 0) {
    $Parent = $PWD
}
Else {
    $Parent = Resolve-Path -Path $Parent
}
$output = Join-Path $Parent (Split-Path -Path $OutFile -Leaf)
$xmlDoc.Save($output)
Write-Output $output
