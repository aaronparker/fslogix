<#PSScriptInfo

.VERSION 0.1

.GUID 118b1874-d4b2-45bc-a698-f91f9568416c

.AUTHOR Aaron Parker

.COMPANYNAME stealthpuppy

.COPYRIGHT 2019, Aaron Parker. All rights reserved.

.TAGS FSLogix Profile-Containers

.LICENSEURI https://github.com/aaronparker/FSLogix/blob/master/LICENSE

.PROJECTURI https://github.com/aaronparker/FSLogix/tree/master/Redirections

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
First version

.PRIVATEDATA
#>
#Requires -Version 3
<#
    .SYNOPSIS
        Converts an input CSV file into an FSLogix Redirections.xml

    .DESCRIPTION
        Converts an input CSV file into an FSLogix Redirections.xml

    .PARAMETER Redirections
        The URI to the Redirections.csv hosted in the FSLogix repo.

    .PARAMETER OutFile
        A local file to save the output to. The default output file will be Redirections.xml in the curent directory.
        
    .NOTES
        Author: Aaron Parker
        Twitter: @stealthpuppy

    .LINK
        https://stealthpuppy.com

    .EXAMPLE
        ConvertTo-RedirectionsXml.ps1

        Output Redirections.xml to the current directory.

    .EXAMPLE
        ConvertTo-RedirectionsXml.ps1 -OutFile C:\Temp\Redirections.xml

        Output Redirections.xml to the C:\Temp\Redirections.xml.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)]
    [string] $Redirections = "https://raw.githubusercontent.com/aaronparker/FSLogix/master/Redirections/Redirections.csv",

    [Parameter(Mandatory = $false)]
    [string] $OutFile = "Redirections.xml"
)

# Read the file and convert from CSV
Try {
    $Paths = (Invoke-WebRequest -Uri $Redirections -UseBasicParsing).Content | ConvertFrom-Csv
}
Catch {
    Write-Error -Message "Failed to read source file."
}

If ($Null -eq $Paths) {
    Write-Warning -Message "List of paths is null."
}
Else {
    # Create the XML document
    [xml] $xmlDoc = New-Object System.Xml.XmlDocument
    $declaration = $xmlDoc.CreateXmlDeclaration("1.0", "UTF-8", $Null)
    $xmlDoc.AppendChild($declaration) | Out-Null

    # Add a comment with generation details
    $comment = "Generated $(Get-Date -Format yyyy-MM-dd) from $Redirections"
    $xmlDoc.AppendChild($xmlDoc.CreateComment($comment)) | Out-Null

    # Create the FrxProfileFolderRedirection root node
    $root = $xmlDoc.CreateNode("element", "FrxProfileFolderRedirection", $Null)
    $root.SetAttribute("ExcludeCommonFolders", "0")

    # Create the Excludes child node of FrxProfileFolderRedirection
    $excludes = $xmlDoc.CreateNode("element", "Excludes", $Null)
    ForEach ($path in ($Paths | Where-Object { $_.Action -eq "Exclude" })) {
        $node = $xmlDoc.CreateElement("Exclude")
        $node.SetAttribute("Copy", $path.Copy)
        $node.InnerText = $path.Path
        $excludes.AppendChild($node) | Out-Null
    }
    $root.AppendChild($excludes) | Out-Null

    # Create the Includes child node of FrxProfileFolderRedirection
    $includes = $xmlDoc.CreateNode("element", "Includes", $Null)
    ForEach ($path in ($Paths | Where-Object { $_.Action -eq "Include" })) {
        $node = $xmlDoc.CreateElement("Include")
        $node.SetAttribute("Copy", $path.Copy)
        $node.InnerText = $path.Path
        $includes.AppendChild($node) | Out-Null
    }
    $root.AppendChild($includes) | Out-Null

    # Append the FrxProfileFolderRedirection root node to the XML document
    $xmlDoc.AppendChild($root) | Out-Null

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

    # Write the output file path to the pipeline
    Write-Output $output
}
