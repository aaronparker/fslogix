<#
    .SYNOPSIS
        Create a container and copy in target OST/PST file

    .NOTES
        Original: https://github.com/FSLogix/Fslogix.Powershell.Disk/tree/main/Dave%20Young/Ost%20Migration/Release
        Use FsLogix.PowerShell.Disk from: https://github.com/aaronparker/fslogix/tree/main/Modules/Fslogix.Powershell.Disk
#>

[CmdletBinding(SupportsShouldProcess = $True)]
Param (
    [Parameter(Mandatory = $False)]
    # AD group name for target users for migration
    [System.String] $Group = "FSLogix-Office365Container-Migrate",

    [Parameter(Mandatory = $False)]
    # Location of the target OST / PST file
    [System.String] $DataFilePath = "\\ad1\Home\%username%",

    [Parameter(Mandatory = $False)]
    # Network location of the FSLogix Containers
    [System.String] $VHDLocation = "\\ad1\FSLogixContainers\RDS",

    [Parameter(Mandatory = $False)]
    [System.String[]] $FileType = ("*.ost", "*.pst"),

    [Parameter(Mandatory = $False)]
    # Target location in the new ODFC container
    [System.String] $ODFCPath = "ODFC",

    [Parameter(Mandatory = $False)]
    # Flip flip SID and username in folder name
    [System.Management.Automation.SwitchParameter] $FlipFlop,

    [Parameter(Mandatory = $False)]
    # Maximum VHD size in MB
    [System.String] $VHDSize = 30000,

    [Parameter(Mandatory = $False)]
    # Maximum VHD size in MB
    [ValidateSet('0', '1')]
    [System.Int32] $VhdIsDynamic = 1,

    [Parameter(Mandatory = $False)]
    # True to initialize driveletter, false to mount to path
    [System.Management.Automation.SwitchParameter] $AssignDriveLetter,

    [Parameter(Mandatory = $False)]
    # Remove user account from target AD group after migration
    [System.Management.Automation.SwitchParameter] $RemoveFromGroup,

    [Parameter(Mandatory = $False)]
    # Rename old Outlook data file/s
    [System.Management.Automation.SwitchParameter] $RenameOldDataFile,

    [Parameter(Mandatory = $False)]
    # Rename directory containing Outlook data file/s
    [System.Management.Automation.SwitchParameter] $RenameOldDirectory,

    [Parameter(Mandatory = $False)]
    # Log file path
    [System.String] $LogFile
)

Set-StrictMode -Version Latest
#Requires -RunAsAdministrator
#Requires -Modules "ActiveDirectory"
#Requires -Modules "Hyper-V"
#Requires -Modules "FsLogix.PowerShell.Disk"

#region Functions
Function Get-LineNumber() {
    $MyInvocation.ScriptLineNumber
}

Function Invoke-Process {
    <#PSScriptInfo 
    .VERSION 1.4 
    .GUID b787dc5d-8d11-45e9-aeef-5cf3a1f690de 
    .AUTHOR Adam Bertram 
    .COMPANYNAME Adam the Automator, LLC 
    .TAGS Processes 
    #>

    <# 
    .DESCRIPTION 
    Invoke-Process is a simple wrapper function that aims to "PowerShellyify" launching typical external processes. There 
    are lots of ways to invoke processes in PowerShell with Start-Process, Invoke-Expression, & and others but none account 
    well for the various streams and exit codes that an external process returns. Also, it's hard to write good tests 
    when launching external proceses. 
 
    This function ensures any errors are sent to the error stream, standard output is sent via the Output stream and any 
    time the process returns an exit code other than 0, treat it as an error. 
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $FilePath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String] $ArgumentList
    )

    $ErrorActionPreference = 'Stop'

    try {
        $stdOutTempFile = "$env:TEMP\$((New-Guid).Guid)"
        $stdErrTempFile = "$env:TEMP\$((New-Guid).Guid)"

        $startProcessParams = @{
            FilePath               = $FilePath
            ArgumentList           = $ArgumentList
            RedirectStandardError  = $stdErrTempFile
            RedirectStandardOutput = $stdOutTempFile
            Wait                   = $true;
            PassThru               = $true;
            NoNewWindow            = $true;
        }
        if ($PSCmdlet.ShouldProcess("Process [$($FilePath)]", "Run with args: [$($ArgumentList)]")) {
            $cmd = Start-Process @startProcessParams
            $cmdOutput = Get-Content -Path $stdOutTempFile -Raw
            $cmdError = Get-Content -Path $stdErrTempFile -Raw
            if ($cmd.ExitCode -ne 0) {
                if ($cmdError) {
                    throw $cmdError.Trim()
                }
                if ($cmdOutput) {
                    throw $cmdOutput.Trim()
                }
            }
            else {
                if ([System.String]::IsNullOrEmpty($cmdOutput) -eq $false) {
                    Write-Output -InputObject $cmdOutput
                }
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        Remove-Item -Path $stdOutTempFile, $stdErrTempFile -Force -ErrorAction Ignore
    }
} # Invoke-Process

Function Write-Log {
    [CmdletBinding(DefaultParametersetName = "LOG")]
    Param (
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0,
            ParameterSetName = 'LOG')]
        [ValidateNotNullOrEmpty()]
        [System.String] $Message,

        [Parameter(Mandatory = $false,
            Position = 1,
            ParameterSetName = 'LOG')]
        [ValidateSet("Error", "Warn", "Info")]
        [System.String] $Level = "Info",

        [Parameter(Mandatory = $false,
            Position = 2)]
        [System.String] $Path = "$env:temp\PowershellScript.log",

        [Parameter(Mandatory = $false,
            Position = 3,
            ParameterSetName = 'STARTNEW')]
        [System.Management.Automation.SwitchParameter] $StartNew,

        [Parameter(Mandatory = $false,
            Position = 4,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'EXCEPTION')]
        [System.Management.Automation.ErrorRecord]$Exception
    )
    BEGIN {
        Set-StrictMode -version Latest
        $expandedParams = $null
        $PSBoundParameters.GetEnumerator() | ForEach-Object { $expandedParams += ' -' + $_.key + ' '; $expandedParams += $_.value }
        Write-Verbose -Message "Starting: $($MyInvocation.MyCommand.Name)$expandedParams"
    }
    PROCESS {
        Switch ($PSCmdlet.ParameterSetName) {
            EXCEPTION {
                Write-Log -Level Error -Message $Exception.Exception.Message -Path $Path
                break
            }
            STARTNEW {
                Remove-Item $Path -Force -ErrorAction SilentlyContinue
                Write-Log 'Starting Logfile' -Path $Path
                break
            }
            LOG {
                $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                switch ( $Level ) {
                    'Error' { $LevelText = 'ERROR:  '; break }
                    'Warn' { $LevelText = 'WARNING:'; break }
                    'Info' { $LevelText = 'INFO:   '; break }
                }

                $logmessage = "$FormattedDate $LevelText $Message"
                $logmessage | Add-Content -Path $Path
            }
        }
    }
    END {
        # Write-Verbose -Message "Finished: $($MyInvocation.Mycommand)"
    }
} # Write-Log
#endregion

# Script
# Build log file path
If ($PSBoundParameters.ContainsKey('$LogFile')) {
    Write-Verbose -Message "Log file at: $LogFile."
}
Else {
    $stampDate = Get-Date
    $scriptName = ([System.IO.Path]::GetFileNameWithoutExtension($(Split-Path $script:MyInvocation.MyCommand.Path -Leaf)))
    $LogFile = Join-Path $PWD ($scriptName + "-" + $stampDate.ToFileTimeUtc() + ".log")
    Write-Verbose -Message "Log file at: $LogFile."
}
$PSDefaultParameterValues += @{
    'Write-Log:Path'    = $LogFile
    'Write-Log:Verbose' = $False
    'Write-Log:WhatIf'  = $False
}
Write-Log -Message "Start FSLogix Container / Outlook data file migration."

# Validate Frx.exe is installed.
Try {
    $FrxPath = Confirm-Frx -Passthru -ErrorAction Stop
    Write-Log -Message "Frx path: $FrxPath."
}
Catch {
    Write-Warning -Message "Error on line: $(Get-LineNumber)."
    Write-Log -Level Warn -Message "Error on line: $(Get-LineNumber)."
    Write-Error $Error[0]
    Write-Log -Level Error -Message $Error[0]
    Exit
}

# Move to the frx install path and grab the path to frx.exe
Try {
    Push-Location -Path (Split-Path -Path $FrxPath -Parent)
    $cmd = Resolve-Path -Path ".\frx.exe"
    Pop-Location
}
Catch {
    Write-Warning -Message "Error on line: $(Get-LineNumber)."
    Write-Log -Level Warn -Message "Error on line: $(Get-LineNumber)."
    Write-Error $Error[0]
    Write-Log -Level Error -Message $Error[0]
    Exit
}
Write-Verbose -Message "Frx.exe path is: $cmd."

#region Get group members from target migration AD group
# Modify to open a CSV list of usernames + OST/PST paths
Try {
    $groupMembers = Get-AdGroupMember -Identity $Group -Recursive -ErrorAction Stop
}
Catch {
    Write-Warning -Message "Error on line: $(Get-LineNumber)."
    Write-Log -Level Warn -Message "Error on line: $(Get-LineNumber)."
    Write-Error $Error[0]
    Write-Log -Level Error -Message $Error[0]
}
#endregion

#region Step through each group member to create the container
ForEach ($User in $groupMembers) {

    #region Get the OST/PST file path
    If ($DataFilePath.ToLower().Contains("%username%")) {
        $userDataFilePath = $DataFilePath -replace "%username%", $User.samAccountName
    }
    Else {
        $userDataFilePath = Join-Path $DataFilePath $User.samAccountName
    }
    If (-not(Test-Path -Path $userDataFilePath)) {
        Write-Warning -Message "Invalid Outlook data file path: $userDataFilePath."
        Write-Log -Message "Invalid Outlook data file path: $userDataFilePath."
        Write-Warning -Message "Error on line: $(Get-LineNumber)."
        Write-Log -Level Warn -Message "Error on line: $(Get-LineNumber)."
        Write-Warning -Message "Could not locate Outlook data file path for $($User.samAccountName)."
        Write-Log -Level Warn -Message "Could not locate Outlook data file path for $($User.samAccountName)."
    }
    Else {
        Write-Verbose -Message "Gather Outlook data file path from: $userDataFilePath."
        Write-Log -Message "Gather Outlook data file path from: $userDataFilePath."
        $dataFiles = Get-ChildItem -Path $userDataFilePath -Include $FileType -Recurse
    }
    If (!(Test-Path -Path Variable:\dataFiles)) {
        Write-Warning -Message "No Outlook data files returned in: $userDataFilePath."
        Write-Log -Message "No Outlook data files returned in: $userDataFilePath."
        Write-Warning -Message "Error on line: $(Get-LineNumber)."
        Write-Log -Level Warn -Message "Error on line: $(Get-LineNumber)."
        Write-Warning "Could not locate Outlook data files for: $($User.samAccountName)."
        Write-Log -Level Warn -Message "Could not locate Outlook data files for: $($User.samAccountName)."
    }
    Else {
        Write-Verbose -Message "Successfully obtained Outlook data file/s for: $($User.samAccountName)."
        Write-Log -Message "Successfully obtained Outlook data file/s for: $($User.samAccountName)."
    }
    #endregion

    # Check that data files are returned. Continue with container create/copy if they do
    If (!(Test-Path -Path Variable:\dataFiles)) {
        Write-Verbose -Message "No Outlook data files for user: $($User.samAccountName)."
        Write-Log -Message "No Outlook data files for user: $($User.samAccountName)."
    }
    Else {
        ForEach ($dataFile in $dataFiles) {
            Write-Verbose -Message "Data file for $($User.samAccountName): $dataFile."
            Write-Log -Message "Data file for $($User.samAccountName): $dataFile."
        }

        Write-Verbose -Message "Generate container for: $($User.SamAccountName)."
        Write-Log -Message "Generate container for: $($User.SamAccountName)."

        #region Determine target container folder for the user's container
        Try {
            If ($FlipFlop.IsPresent) {
                Write-Verbose -Message "FlipFlip is present."
                Write-Log -Message "FlipFlip is present."
                $Directory = New-FslDirectory -SamAccountName $User.SamAccountName -SID $User.SID -Destination $VHDLocation `
                    -FlipFlop -Passthru -ErrorAction Stop
            }
            Else {
                Write-Verbose -Message "FlipFlip is not present."
                Write-Log -Message "FlipFlip is not present."
                $Directory = New-FslDirectory -SamAccountName $User.SamAccountName -SID $User.SID -Destination $VHDLocation `
                    -Passthru -ErrorAction Stop
            }
            Write-Verbose -Message "Container directory: $Directory."
            Write-Log -Message "Container directory: $Directory."
        }
        Catch {
            Write-Warning -Message "Error on line: $(Get-LineNumber)."
            Write-Log -Level Warn -Message "Error on line: $(Get-LineNumber)."
            Write-Error $Error[0]
            Write-Log -Level Error -Message $Error[0]
            Exit
        }
        # Construct full VHD path 
        $vhdName = "ODFC_" + $User.SamAccountName + ".vhdx"
        $vhdPath = Join-Path $Directory $vhdName
        Write-Verbose -Message "VHDLocation: $vhdPath."
        Write-Log -Message "VHDLocation: $vhdPath."
        #endregion

        #region Remove the VHD if it exists
        # Modify this to open an existing container
        If (Test-Path -Path $vhdPath) {
            Write-Log -Message "Removing: $vhdPath."
            If ($pscmdlet.ShouldProcess($vhdPath, "Remove")) {
                Remove-Item -Path $vhdPath -Force -ErrorAction SilentlyContinue
            }
        }
        #endregion

        #region Generate the container
        Try {
            $arguments = "create-vhd -filename $vhdPath -size-mbs=$VHDSize -dynamic=$vhdIsDynamic -label $($User.SamAccountName)"
            Write-Log -Message "Invoke: $cmd $arguments"
            If ($pscmdlet.ShouldProcess($vhdPath, "Create VHD")) {
                Invoke-Process -FilePath $cmd -ArgumentList $arguments
            }
        }
        Catch {
            Write-Warning -Message "Error on line: $(Get-LineNumber)."
            Write-Log -Level Warn -Message "Error on line: $(Get-LineNumber)."
            Write-Error $Error[0]
            Write-Log -Level Error -Message $Error[0]
            Exit
        }
        Write-Verbose -Message "Generated new VHD at: $vhdPath"
        #endregion

        #region Confirm the container is good
        Write-Verbose -Message "Validating Outlook container."
        Write-Log -Message "Validating Outlook container."
    
        $FslPath = $VHDLocation.TrimEnd('\%username%')
        Write-Verbose -Message "FslPath is $FslPath."
        Write-Log -Message "FslPath is $FslPath."

        If ($FlipFlop.IsPresent) {
            $IsFslProfile = Confirm-FslProfile -Path $FslPath -SamAccountName $User.samAccountName -SID $User.SID -FlipFlop
        }
        Else {
            $IsFslProfile = Confirm-FslProfile -Path $FslPath -SamAccountName $User.samAccountName -SID $User.SID
        }
        If ($IsFslProfile) {
            Write-Verbose -Message "Validated Outlook container: $FslPath."
            Write-Log -Message "Validated Outlook container: $FslPath."
        }
        Else {
            Write-Error $Error "Could not validate Outlook container: $FslPath."
            Write-Log -Level Error -Message "Could not validate Outlook container: $FslPath."
        }
        #endregion

        #region Apply permissions to the container
        Write-Verbose -Message "Applying security permissions for $($User.samAccountName)."
        Try {
            If ($pscmdlet.ShouldProcess($User.samAccountName, "Add permissions")) {
                Add-FslPermissions -User $User.samAccountName -folder $Directory
            }
            Write-Verbose -Message "Successfully applied security permissions for $($User.samAccountName)."
            Write-Log -Message "Successfully applied security permissions for $($User.samAccountName)."
        }
        Catch {
            Write-Warning -Message "Error on line: $(Get-LineNumber)."
            Write-Log -Level Warn -Message "Error on line: $(Get-LineNumber)."
            Write-Error $Error[0]
            Write-Log -Level Error -Message $Error[0]
            Exit
        }
        #endregion

        #region Mount the container
        Write-Verbose -Message "Mounting FSLogix Container."
        Write-Log -Message "Mounting FSLogix Container."
        Try {
            If ($AssignDriveLetter.IsPresent) {
                If ($pscmdlet.ShouldProcess($vhdPath, "Mount")) {
                    $MountPath = Add-FslDriveLetter -Path $vhdPath -Passthru
                    Write-Verbose -Message "Container mounted at: $MountPath."
                    Write-Log -Message "Container mounted at: $MountPath."
                }
            }
            Else {
                If ($pscmdlet.ShouldProcess($vhdPath, "Mount")) {
                    $Mount = Mount-FslDisk -Path $vhdPath -ErrorAction Stop -PassThru
                    $MountPath = $Mount.Path
                    Write-Verbose -Message "Container mounted at: $MountPath."
                    Write-Log -Message "Container mounted at: $MountPath."
                }
            }
        }
        Catch {
            Write-Warning -Message "Error on line: $(Get-LineNumber)."
            Write-Log -Level Warn -Message "Error on line: $(Get-LineNumber)."
            Write-Error $Error[0]
            Write-Log -Level Error -Message $Error[0]
            Exit
        }
        #endregion

        #region Copy the data files
        Write-Verbose -Message "Copy Outlook data file/s for $($User.samAccountName)."
        Write-Log -Message "Copy Outlook data file/s for $($User.samAccountName)."
        $dataFileDestination = Join-Path $MountPath $ODFCPath
        If (-not (Test-Path -Path $dataFileDestination)) {
            If ($pscmdlet.ShouldProcess($dataFileDestination, "Create")) {
                New-Item -ItemType Directory -Path $dataFileDestination -Force | Out-Null
                Write-Verbose -Message "Created path: $dataFileDestination."
                Write-Log -Message "Created path: $dataFileDestination."
            }
        }
        ForEach ($dataFile in $dataFiles) {
            Try {
                Write-Verbose -Message "Copy file $($dataFile.FullName) to $ODFCPath."
                Write-Log -Message "Copy file $($dataFile.FullName) to $ODFCPath."
                If ($pscmdlet.ShouldProcess($dataFile.FullName, "Copy to disk")) {
                    Copy-FslToDisk -VHD $vhdPath -Path $dataFile.FullName -Destination $ODFCPath -ErrorAction Stop
                }
            }
            Catch {
                Dismount-FslDisk -Path $vhdPath
                Write-Warning -Message "Error on line: $(Get-LineNumber)."
                Write-Log -Level Warn -Message "Error on line: $(Get-LineNumber)."
                Write-Error $Error[0]
                Write-Log -Level Error -Message $Error[0]
                Exit
            }
        }
        #endregion

        #region Rename the old Outlook data file/s; rename folders; remove user from group
        If ($RenameOldDataFile.IsPresent) {
            ForEach ($dataFile in $dataFiles) {
                Try {
                    If ($pscmdlet.ShouldProcess($dataFile.FullName, "Rename")) {
                        Write-Verbose -Message "Rename [$($dataFile.FullName)] to [$($dataFile.BaseName).old]."
                        Rename-Item -Path $dataFile.FullName -NewName "$($dataFile.BaseName).old" -Force -ErrorAction Stop
                    }
                }
                Catch {
                    Write-Warning -Message "Error on line: $(Get-LineNumber)."
                    Write-Log -Level Warn -Message "Error on line: $(Get-LineNumber)."
                    Write-Error $Error[0]
                    Write-Log -Level Error -Message $Error[0]
                }
            }
        }
        If ($RenameOldDirectory.IsPresent) {
            If ($Null -ne $userDataFilePath) {
                Try {
                    Write-Verbose -Message "Renaming old Outlook data file directory"
                    If ($pscmdlet.ShouldProcess($userDataFilePath, "Rename")) {
                        Rename-Item -Path $userDataFilePath -NewName "$($userDataFilePath)_Old" -Force -ErrorAction Stop
                    }
                }
                Catch {
                    Write-Warning -Message "Error on line: $(Get-LineNumber)."
                    Write-Log -Level Warn -Message "Error on line: $(Get-LineNumber)."
                    Write-Error $Error[0]
                    Write-Log -Level Error -Message $Error[0]
                }
                Write-Verbose -Message "Successfully renamed old Outlook data file directory: $userDataFilePath."
                Write-Log -Message "Successfully renamed old Outlook data file directory: $userDataFilePath."
            }
            Else {
                Write-Verbose -Message "Skipping rename directory for user: $User."
                Write-Log -Message "Skipping rename directory for user: $User."
            }
        }
        If ($RemoveFromGroup.IsPresent) {
            Try {
                Write-Verbose -Message "Removing $($User.samAccountName) from AD group: $Group."
                Write-Log -Message "Removing $($User.samAccountName) from AD group: $Group."
                If ($pscmdlet.ShouldProcess($User.samAccountName, "Remove from group")) {
                    Remove-ADGroupMember -Identity $Group -Members $User.samAccountName -ErrorAction Stop
                }
            }
            Catch {
                Write-Warning -Message "Error on line: $(Get-LineNumber)."
                Write-Log -Level Warn -Message "Error on line: $(Get-LineNumber)."
                Write-Error $Error[0]
                Write-Log -Level Error -Message $Error[0]
            }
            Write-Verbose -Message "Successfully removed $($User.samAccountName) from AdGroup: $Group."
            Write-Log -Message "Successfully removed $($User.samAccountName) from AdGroup: $Group."
        }
        #endregion

        Write-Verbose -Message "Successfully migrated Outlook data file for $($User.samAccountName)."
        Write-Log -Message "Successfully migrated Outlook data file for $($User.samAccountName)."
        Write-Verbose -Message "Dismounting container."
        Write-Log -Message "Dismounting container."
        Try {
            If ($pscmdlet.ShouldProcess($vhdPath, "Dismount")) {
                Dismount-FslDisk -Path $vhdPath -ErrorAction Stop
                Write-Verbose -Message "Dismounted container."
            }
        }
        Catch {
            Write-Warning -Message "Error on line: $(Get-LineNumber)."
            Write-Log -Level Warn -Message "Error on line: $(Get-LineNumber)."
            Write-Error $Error[0]
            Write-Log -Level Error -Message $Error[0]
            Exit
        }

        # Remove variables to ensure clean environment for next user account
        Remove-Variable dataFiles
    }
}

Write-Log -Message "Migration complete."
#endregion
