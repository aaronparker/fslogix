#Requires -RunAsAdministrator
#Requires -Module FSLogix.Powershell.Rules
#Requires -PSEdition Desktop
<#
    .SYNOPSIS
        Creates FSLogix App Masking rule sets for Microsoft Office applications using the FSLogix.Powershell.Rules module.

        Outputs files in "Documents\FSLogix Rule Sets". Rule sets will require manual validation.

    .EXAMPLE
        To create an FSLogix App Masking rule set for Visio:

        C:\> .\New-Ruleset.ps1
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [System.String[]] $FileList
)

begin {
    #region Functions
    function Convert-Path {
        <#
            .SYNOPSIS
            Replaces paths with environment variables
        #>
        param (
            [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
            [System.String] $Path
        )
        switch ($Path) {
            { $_ -match "HKEY_LOCAL_MACHINE" } { $Path = $Path -replace "HKEY_LOCAL_MACHINE", "HKLM" }
            { $_ -match "C:\\Program Files \(x86\)" } { $Path = $Path -replace "C:\\Program Files \(x86\)", "%ProgramFilesFolder32%" }
            { $_ -match "C:\\Program Files" } { $Path = $Path -replace "C:\\Program Files", "%ProgramFilesFolder64%" }
            { $_ -match "C:\\ProgramData\\Microsoft\\Windows\\Start Menu" } { $Path = $Path -replace "C:\\ProgramData\\Microsoft\\Windows\\Start Menu", "%CommonStartMenuFolder%" }
            { $_ -match "C:\\ProgramData" } { $Path = $Path -replace "C:\\ProgramData", "%CommonAppDataFolder%" }
        }
        Write-Output -InputObject $Path
    }

    function Remove-InvalidFileNameChars {
        param(
            [System.String] $Name
        )
        $invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
        $replaceChars = "[{0}]" -f [RegEx]::Escape($invalidChars)
        Write-Output -InputObject ($Name -replace $replaceChars)
    }
    #endregion

    # Set up the rule set file paths
    $Documents = [Environment]::GetFolderPath('MyDocuments')
    #$FileName = Remove-InvalidFileNameChars -Name $SearchString[0]
    $RulesetFile = [System.IO.Path]::Combine($Documents, "FSLogix Rule Sets", "Microsoft$FileName.fxr")
    
    # Create the 'FSLogix Rule Sets'
    if (!(Test-Path -Path (Split-Path -Path $RulesetFile -Parent))) {
        $params = @{
            Path        = (Split-Path -Path $RulesetFile -Parent)
            ItemType    = "Directory"
            Force       = $true
            ErrorAction = "SilentlyContinue"
        }
        New-Item @params | Out-Null
    }
}

process {
    if (Test-Path -Path $(Split-Path -Path $RulesetFile -Parent)) {
        if (Test-Path -Path $RulesetFile) {
            Write-Warning -Message "File exists: $RulesetFile. Rules will be added to the existing file."
        }
        Write-Information -MessageData "INFO: Using rule set file: $RulesetFile." -InformationAction "Continue"

        # Write paths to the App Masking rule set file
        Write-Verbose -Message "Add file rules to: $RulesetFile."
        foreach ($file in $FileList) {
            $params = @{
                RuleFilePath = $RulesetFile
                FullName     = (Convert-Path -Path $file)
                HidingType   = "FileOrValue"
                Comment      = "Added by $($MyInvocation.MyCommand)."
            }
            Add-FslRule @params
        }

        # Output the location of the rule set file
        Write-Output -InputObject $RulesetFile
    }
    else {
        Write-Error -Message "Path does not exist: $(Split-Path -Path $RulesetFile -Parent)."
    }
}

end {
}
