<#
    .SYNOPSIS
        Create a container and copy in target OST/PST files

    .NOTES
        Use FsLogix.PowerShell.Disk from: https://github.com/aaronparker/fslogix/tree/main/Modules/Fslogix.Powershell.Disk
#>

[CmdletBinding(SupportsShouldProcess = $True)]
Param (
    [Parameter(Mandatory = $True)]
    # Path to a list of usernames with Outlook data file paths
    [ValidateScript( {
            If (Test-Path -Path $_ -PathType 'Leaf') {
                Return $True
            }
            Else {
                Throw "Cannot find path $_"
            }
        })]
    [System.String] $DataFileList,

    [Parameter(Mandatory = $False)]
    # Top level OU to search for user accounts to speed searching
    [System.String] $SearchBase,

    [Parameter(Mandatory = $False)]
    # Active Directory Domain Controller to search against
    [System.String] $SearchServer,

    [Parameter(Mandatory = $False)]
    # Network location of the FSLogix Containers
    [System.String] $VHDLocation = "\\ad1\FSLogixContainers\RDS",

    [Parameter(Mandatory = $False)]
    # Target location in the new ODFC container
    [System.String] $ODFCPath = "ODFC",

    [Parameter(Mandatory = $False)]
    # Flip flop SID and username in folder name
    [System.Management.Automation.SwitchParameter] $FlipFlop,

    [Parameter(Mandatory = $False)]
    # Use the user's UPN instead of the SamAccountName in the user directory
    [System.Management.Automation.SwitchParameter] $UseUpn,

    [Parameter(Mandatory = $False)]
    # Maximum VHD size in MB
    [ValidateRange(256, 67108864)]
    [System.Int32] $VHDSizeMB = 30720,

    [Parameter(Mandatory = $False)]
    # Maximum VHD size in MB
    [ValidateSet('0', '1')]
    [System.Int32] $VhdIsDynamic = 1,

    [Parameter(Mandatory = $False)]
    # True to initialize driveletter, false to mount to path
    [System.Management.Automation.SwitchParameter] $AssignDriveLetter,

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
            $frx = Start-Process @startProcessParams
            $cmdOutput = Get-Content -Path $stdOutTempFile -Raw
            $cmdError = Get-Content -Path $stdErrTempFile -Raw
            if ($frx.ExitCode -ne 0) {
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
        [System.String] $Path = (Join-Path $env:Temp "PowershellScript.log"),

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
If ($PSBoundParameters.ContainsKey('LogFile')) {
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
    Write-Error $Error[0]
    Write-Log -Level Error -Message $Error[0]
    Exit
}

# Move to the frx install path and grab the path to frx.exe
Try {
    Push-Location -Path (Split-Path -Path $FrxPath -Parent)
    $frx = Resolve-Path -Path ".\frx.exe"
    Pop-Location
}
Catch {
    Write-Error $Error[0]
    Write-Log -Level Error -Message $Error[0]
    Exit
}
Write-Verbose -Message "Frx.exe path is: $frx."

#region Get group members from target migration AD group
# Modify to open a CSV list of usernames + OST/PST paths
try {
    $fileList = Get-Content -Path $DataFileList -ErrorAction SilentlyContinue | ConvertFrom-Csv
}
catch {
    Write-Error -Message "Failed to read: $DataFileList"
}

#region Step through each group member to create the container
If ($Null -ne $fileList) {

    $userFiles = $fileList | Group-Object -Property samAccountName
    ForEach ($user in $userFiles) {

        Write-Log -Message "Start migration for [$($user.Name)]."
        # Find user account in AD
        Try {
            $AdUserParam = @{
                Identity    = $user.Name
                ErrorAction = "SilentlyContinue"
            }
            If ($PSBoundParameters.ContainsKey('SearchBase')) { $AdUserParam.SearchBase = $SearchBase }
            If ($PSBoundParameters.ContainsKey('SearchServer')) { $AdUserParam.Server = $SearchServer }
            Write-Verbose -Message "Searching AD for samAccountName: [$($user.Name)]."
            Write-Log -Message "Searching AD for samAccountName: [$($user.Name)]."
            $UserAccount = Get-ADUser @AdUserParam
        }
        Catch {
            Write-Warning -Message "Failed to find $($user.Name)."
            Write-Log -Level Warn "Failed to find $($user.Name)."
            Write-Log -Level Error -Message $Error[0]
        }
        
        If ($UserAccount) {
            #region Determine target container folder for the user's container
            Try {
                $FslDirParam = @{
                    SID         = $UserAccount.SID
                    Destination = $VHDLocation
                    Passthru    = $True
                    ErrorAction = "Stop"
                }
                If ($PSBoundParameters.ContainsKey('UseUpn')) {
                    Write-Verbose -Message "UseUpn is present. Using UserPrincipalName in FslDir."
                    Write-Log -Message "UseUpn is present. Using UserPrincipalName in FslDir."
                    $FslDirParam.SamAccountName = $UserAccount.UserPrincipalName
                }
                Else {
                    Write-Verbose -Message "Using SamAccountName in FslDir."
                    Write-Log -Message "Using SamAccountName in FslDir."
                    $FslDirParam.SamAccountName = $UserAccount.SamAccountName
                }
                If ($PSBoundParameters.ContainsKey('FlipFlop')) {
                    Write-Verbose -Message "FlipFlip is present."
                    Write-Log -Message "FlipFlip is present."
                    $FslDirParam.FlipFlop = $True
                }
                $Directory = New-FslDirectory @FslDirParam
                Write-Verbose -Message "Container directory: $Directory."
                Write-Log -Message "Container directory: $Directory."
            }
            Catch {
                Write-Error $Error[0]
                Write-Log -Level Error -Message $Error[0]
                Exit
            }
            # Construct full VHD path 
            $vhdName = "ODFC_$($UserAccount.SamAccountName).vhdx"
            $vhdPath = Join-Path -Path $Directory -ChildPath $vhdName
            Write-Verbose -Message "VHDLocation: $vhdPath."
            Write-Log -Message "VHDLocation: $vhdPath."
            #endregion

            #region Create container
            If (Test-Path -Path $vhdPath) {
                Write-Verbose -Message "Container exists: $vhdPath."
                Write-Log -Message "Container exists: $vhdPath."
            }
            Else {
                Write-Verbose -Message "No existing container at: $vhdPath."
                Write-Log -Message "No existing container at: $vhdPath."
                #region Generate the container
                Try {
                    $VHDSizeMB = $VHDSizeMB -as [System.String]
                    $arguments = "create-vhd -filename $vhdPath -size-mbs=$VHDSizeMB -dynamic=$vhdIsDynamic -label $($UserAccount.SamAccountName)"
                    Write-Verbose -Message "Invoke: $frx $arguments"
                    Write-Log -Message "Invoke: $frx $arguments"
                    If ($pscmdlet.ShouldProcess($vhdPath, "Create VHD")) {
                        Invoke-Process -FilePath $frx -ArgumentList $arguments
                    }
                }
                Catch {
                    Write-Error $Error[0]
                    Write-Log -Level Error -Message $Error[0]
                    Exit
                }
                Write-Verbose -Message "Generated new VHD at: $vhdPath"
                Write-Log -Message "Generated new VHD at: $vhdPath"
            }
            #endregion

            #region Confirm the container is good
            Write-Verbose -Message "Validating Outlook container."
            Write-Log -Message "Validating Outlook container."
    
            $FslPath = $VHDLocation.TrimEnd('\%username%')
            Write-Verbose -Message "FslPath is $FslPath."
            Write-Log -Message "FslPath is $FslPath."

            $FslProfParam = @{
                Path           = $FslPath
                SamAccountName = $UserAccount.samAccountName
                SID            = $UserAccount.SID
            }
            If ($PSBoundParameters.ContainsKey('UseUpn')) {
                Write-Verbose -Message "UseUpn is present. Using UserPrincipalName in FslDir."
                Write-Log -Message "UseUpn is present. Using UserPrincipalName in FslDir."
                $FslProfParam.SamAccountName = $UserAccount.UserPrincipalName
            }
            Else {
                Write-Verbose -Message "Using SamAccountName in FslDir."
                Write-Log -Message "Using SamAccountName in FslDir."
                $FslProfParam.SamAccountName = $UserAccount.SamAccountName
            }
            If ($PSBoundParameters.ContainsKey('FlipFlop')) {
                Write-Verbose -Message "FlipFlip is present."
                Write-Log -Message "FlipFlip is present."
                $FslProfParam.FlipFlop = $True
            }
            $IsFslProfile = Confirm-FslProfile @FslProfParam

            If ($IsFslProfile) {
                Write-Verbose -Message "Validated Outlook container: $FslPath."
                Write-Log -Message "Validated Outlook container: $FslPath."
            }
            Else {
                Write-Error $Error[0] #"Could not validate Office 365 Container: $FslPath."
                Write-Log -Level Error -Message "Could not validate Office 365 Container: $FslPath."
            }
            #endregion

            #region Apply permissions to the Container directory
            Write-Verbose -Message "Applying security permissions for $($UserAccount.samAccountName) to $Directory."
            Write-Log -Message "Applying security permissions for $($UserAccount.samAccountName) to $Directory."
            Try {
                If ($pscmdlet.ShouldProcess($UserAccount.samAccountName, "Add permissions")) {
                    Add-FslPermissions -User $UserAccount.samAccountName -Folder $Directory
                }
                Write-Verbose -Message "Successfully applied security permissions for $($UserAccount.samAccountName) to $Directory."
                Write-Log -Message "Successfully applied security permissions for $($UserAccount.samAccountName) to $Directory."
            }
            Catch {
                Write-Error $Error[0]
                Write-Log -Level Error -Message $Error[0]
                Exit
            }
            #endregion

            #region Mount the container
            Write-Verbose -Message "Mounting FSLogix Container: $vhdPath ."
            Write-Log -Message "Mounting FSLogix Container: $vhdPath."
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
                Write-Error $Error[0]
                Write-Log -Level Error -Message $Error[0]
                Exit
            }
            #endregion

            # Create destination
            Write-Verbose -Message "Copy Outlook data file/s for $($UserAccount.samAccountName)."
            Write-Log -Message "Copy Outlook data file/s for $($UserAccount.samAccountName)."
            $dataFileDestination = Join-Path -Path $MountPath -ChildPath $ODFCPath
            If (-not (Test-Path -Path $dataFileDestination)) {
                If ($pscmdlet.ShouldProcess($dataFileDestination, "Create")) {
                    New-Item -ItemType Directory -Path $dataFileDestination -Force | Out-Null
                    Write-Verbose -Message "Created path: $dataFileDestination."
                    Write-Log -Message "Created path: $dataFileDestination."
                }
                If ($pscmdlet.ShouldProcess($dataFileDestination, "Set permissions")) {
                    Add-FslPermissions -User $UserAccount.samAccountName -Folder $dataFileDestination -Inherit
                    Write-Verbose -Message "Set permissions for $($UserAccount.samAccountName) on path: $dataFileDestination."
                    Write-Log -Message "Set permissions for $($UserAccount.samAccountName) on path: $dataFileDestination."
                }
            }

            #region Copy the data files
            ForEach ($file in $user.Group) {
                Try {
                    Write-Verbose -Message "Copy file $($file.Path) to $vhdPath."
                    Write-Log -Message "Copy file $($file.Path) to $vhdPath."
                    If ($pscmdlet.ShouldProcess($file.Path, "Copy to disk")) {
                        Copy-FslToDisk -VHD $vhdPath -Path $file.Path -Destination $ODFCPath -ErrorAction Stop
                    }
                }
                Catch {
                    Write-Error $Error[0]
                    Write-Log -Level Error -Message $Error[0]
                }
            }
            #endregion

            Write-Verbose -Message "Successfully migrated Outlook data file for $($UserAccount.samAccountName)."
            Write-Log -Message "Successfully migrated Outlook data file for $($UserAccount.samAccountName)."
            Try {
                If ($pscmdlet.ShouldProcess($vhdPath, "Dismount")) {
                    Write-Verbose -Message "Dismounting container."
                    Write-Log -Message "Dismounting container."
                    Dismount-FslDisk -Path $vhdPath -ErrorAction Stop
                }
            }
            Catch {
                Write-Error $Error[0]
                Write-Log -Level Error -Message $Error[0]
                Exit
            }

            #region Apply permissions to the Container itself
            Write-Verbose -Message "Applying security permissions for $($UserAccount.samAccountName) to $vhdPath."
            Write-Log -Message "Applying security permissions for $($UserAccount.samAccountName) to $vhdPath."
            Try {
                If ($pscmdlet.ShouldProcess($UserAccount.samAccountName, "Add permissions")) {
                    Add-FslPermissions -User $UserAccount.samAccountName -File $vhdPath
                }
                Write-Verbose -Message "Successfully applied security permissions for $($UserAccount.samAccountName) to $vhdPath."
                Write-Log -Message "Successfully applied security permissions for $($UserAccount.samAccountName) to $vhdPath."
            }
            Catch {
                Write-Error $Error[0]
                Write-Log -Level Error -Message $Error[0]
                Exit
            }
            #endregion
        }
    }
}
Write-Verbose -Message "Migration complete."
Write-Log -Message "Migration complete."
#endregion
