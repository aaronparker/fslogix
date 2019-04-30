<#PSScriptInfo

.VERSION 1.0.2

.GUID 118b1874-d4b2-45bc-a698-f91f9568416c

.AUTHOR Aaron Parker

.COMPANYNAME stealthpuppy

.COPYRIGHT 2019, Aaron Parker. All rights reserved.

.TAGS FSLogix Profile-Containers Profile

.DESCRIPTION Converts a correctly formatted input CSV file into an FSLogix Redirections.xml for use with FSLogix Profile Containers. Downloads the redirections data from the source repo hosted on GitHub and converts the input CSV file into an FSLogix Redirections.xml.

.LICENSEURI https://github.com/aaronparker/FSLogix/blob/master/LICENSE

.PROJECTURI https://github.com/aaronparker/FSLogix/tree/master/Redirections

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
    - April 2019, 1.0.1, Initial version
    - April 2019, 1.0.2, Support local Redirections.csv as input

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
        https://stealthpuppy.com

    .EXAMPLE
        ConvertTo-RedirectionsXml.ps1

        Output Redirections.xml to the current directory.

    .EXAMPLE
        ConvertTo-RedirectionsXml.ps1 -OutFile C:\Temp\Redirections.xml

        Output Redirections.xml to the C:\Temp\Redirections.xml.
#>
[CmdletBinding(SupportsShouldProcess = $True, HelpURI = "https://github.com/aaronparker/FSLogix/blob/master/Redirections/README.MD")]
[OutputType([String])]
Param (
    [Parameter(Mandatory = $false)]
    [string] $Redirections = "https://raw.githubusercontent.com/aaronparker/FSLogix/master/Redirections/Redirections.csv",

    [Parameter(Mandatory = $false)]
    [string] $OutFile = "Redirections.xml"
)

# Read the file and convert from CSV. Support https or local file source
If ($Redirections -match "http.*://") {
    Try {
        $Content = Invoke-WebRequest -Uri $Redirections -UseBasicParsing
    }
    Catch {
        Throw "Failed to read source file at $Redirections. Check that the URI exists or this machine has access to the internet."
    }
    # Convert the content from CSV into an object
    If ($Null -ne $Content) {
        Try {
            $Paths = $Content.Content | ConvertFrom-Csv
        }
        Catch {
            Throw "Failed to convert CSV content."
        }
    }
}
Else {
    If (Test-Path -Path (Resolve-Path -Path $Redirections)) {
        Try {
            $Content = Get-Content -Path (Resolve-Path -Path $Redirections) -Raw
        }
        Catch {
            Throw "Failed to read source file at $Redirections. Check that the file content is valid."
        }
    }
    Else {
        Throw "Failed to read source file at $Redirections. Check that the path exists."
    }
    # Convert the content from CSV into an object
    If ($Null -ne $Content) {
        Try {
            $Paths = $Content | ConvertFrom-Csv
        }
        Catch {
            Throw "Failed to convert CSV content."
        }
    }
}

# Convert
If ($Null -eq $Paths) {
    Write-Error -Message "List of redirection paths is null."
}
Else {
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
    [xml] $xmlDoc = New-Object System.Xml.XmlDocument
    $declaration = $xmlDoc.CreateXmlDeclaration($xmlVersion, $xmlEncoding, $Null)
    $xmlDoc.AppendChild($declaration) | Out-Null

    # Add a comment with generation details
    $xmlDoc.AppendChild($xmlDoc.CreateComment($xmlComment)) | Out-Null

    # Create the FrxProfileFolderRedirection root node
    $root = $xmlDoc.CreateNode("element", $xmlRootNode, $Null)
    $root.SetAttribute($xmlRootNodeAttribute1, $xmlRootNodeAttribute1Value)

    # Create the Excludes child node of FrxProfileFolderRedirection
    $excludes = $xmlDoc.CreateNode("element", $xmlExcludeNode, $Null)
    ForEach ($path in ($Paths | Where-Object { $_.Action -eq $xmlExcludeNodeElement })) {
        $node = $xmlDoc.CreateElement($xmlExcludeNodeElement)
        $node.SetAttribute($xmlNodeAttribute1, $path.Copy)
        $node.InnerText = $path.Path
        $excludes.AppendChild($node) | Out-Null
    }
    $root.AppendChild($excludes) | Out-Null

    # Create the Includes child node of FrxProfileFolderRedirection
    $includes = $xmlDoc.CreateNode("element", $xmlIncludeNode, $Null)
    ForEach ($path in ($Paths | Where-Object { $_.Action -eq $xmlIncludeNodeElement })) {
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
    If ($Parent.Length -eq 0) {
        $Parent = $PWD
    }
    Else {
        $Parent = Resolve-Path -Path $Parent
    }
    $output = Join-Path $Parent (Split-Path -Path $OutFile -Leaf)

    # Save to an XML file
    Try {
        $xmlDoc.Save($output)
    }
    Catch {
        Throw "Failed when saving XML to path: $output."
    }

    # Write the output file path to the pipeline
    Write-Output $output
}
