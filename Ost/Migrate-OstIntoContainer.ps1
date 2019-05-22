<#
    .SYNOPSIS
        Create a container and copy in target OST/PST file

    .NOTES
        https://github.com/FSLogix/Fslogix.Powershell.Disk/tree/master/Dave%20Young/Ost%20Migration/Release
#>

[CmdletBinding(SupportsShouldProcess = $True)]
[OutputType([String])]
Param (
    [Parameter(Mandatory = $false)]
    # Maximum VHD size in MB
    [string] $VHDSize = 30000,

    [Parameter(Mandatory = $false)]
    # AD group name for target users for migration
    [string] $Group = "FSLogix Migrate",

    [Parameter(Mandatory = $false)]
    # Location of the target OST / PST file
    [string] $DataFilePath = "\\server\users\%username%",

    [Parameter(Mandatory = $false)]
    # Target location in the new ODFC container
    [string] $ODFCPath = "ODFC",

    [Parameter(Mandatory = $false)]
    # Network location of the FSLogix Containers
    [string] $VHDLocation = "\\server\FSLogixContainers",

    [Parameter(Mandatory = $False)]
    [string[]] $FileType = "*.ost"
)

Set-StrictMode -Version Latest
#Requires -RunAsAdministrator
#Requires -Modules "ActiveDirectory"
#Requires -Modules "Hyper-V"
#Requires -Modules "FsLogix.PowerShell.Disk"

# Variables
$ComputerName = $env:COMPUTERNAME
$vhdIsDynamic = 1                   # 1 = dynamic, 0 = fixed
$VerbosePreference = "Continue"     # continue for output, silentlycontinue for no output
$renameOldDataFile = $False         # true to rename old ost with .old extension, false to leave old ost the same
$renameOldDirectory = $True         # true to rename old directory to include _old, false to leave old directory the same
$removeFromAD = $True               # true to remove AD User after sucessful migration, false to keep AD user
$flipFlop = $False                  # true to have directory name SID_Name, false to have directory name Name_SID
$assignDriveLetter = $False         # true to initialize driveletter, false to mount to path

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
        [string] $FilePath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ArgumentList
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
                if ([string]::IsNullOrEmpty($cmdOutput) -eq $false) {
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
}
#endregion

#region Script
## Validate Frx.exe is installed.
Try {
    $FrxPath = Confirm-Frx -Passthru -ErrorAction Stop
}
Catch {
    Write-Warning -Message "Error Code: $(Get-LineNumber)"
    Write-Error $Error[0]
    Exit
}

# Move to the frx install path
Set-Location -path (Split-Path -Path $FrxPath -Parent)

Try {
    # Get AD group members
    If ($pscmdlet.ShouldProcess($Group, "Get member")) {
        $groupMembers = Get-AdGroupMember -Identity $Group -Recursive -ErrorAction Stop
    }
}
Catch {
    Write-Warning -Message "Error Code: $(Get-LineNumber)"
    Write-Error $Error[0]
}

ForEach ($User in $groupMembers) {
    Write-Verbose -Message "Generate container: $($User.SamAccountName)."
    Try {
        If ($flipFlop) {
            $Directory = New-FslDirectory -SamAccountName $User.SamAccountName -SID $User.SID -Destination $VHDLocation `
                -FlipFlop -Passthru -ErrorAction Stop
        }
        Else {
            $Directory = New-FslDirectory -SamAccountName $User.SamAccountName -SID $User.SID -Destination $VHDLocation `
                -Passthru -ErrorAction Stop
        }
        Write-Verbose -Message "Container Directory: $Directory."
    }
    Catch {
        Write-Warning -Message "Error Code: $(Get-LineNumber)"
        Write-Error $Error[0]
        Exit
    }

    $vhdName = "ODFC_" + $User.SamAccountName + ".vhdx"
    $vhdPath = Join-Path $Directory $vhdName
    Write-Verbose -Message "VHDLocation: $vhdPath."

    If (Test-Path -Path $vhdPath) {
        If ($pscmdlet.ShouldProcess($vhdPath, "Remove")) {
            Remove-Item -Path $vhdPath -Force -ErrorAction SilentlyContinue
        }
    }
    Try {
        $cmd = Resolve-Path -Path ".\frx.exe"
        $arguments = "create-vhd -filename $vhdPath -size-mbs=$VHDSize -dynamic=$vhdIsDynamic -label $($User.SamAccountName)"
        If ($pscmdlet.ShouldProcess($vhdPath, "Create VHD")) {
            Invoke-Process -FilePath $cmd -ArgumentList $arguments
        }
    }
    Catch {
        Write-Warning -Message "Error Code: $(Get-LineNumber)"
        Write-Error $Error[0]
        Exit
    }
    Write-Verbose -Message "Generated new VHD at: $vhdPath"

    Write-Verbose -Message "Validating Outlook container."
    $FslPath = $VHDLocation.TrimEnd('\%username%')
    If ($flipFlop) {
        $IsFslProfile = Confirm-FslProfile -Path $FslPath -SamAccountName $User.samAccountName -SID $User.SID -FlipFlop
    }
    Else {
        $IsFslProfile = Confirm-FslProfile -Path $FslPath -SamAccountName $User.samAccountName -SID $User.SID
    }
    If ($IsFslProfile) {
        Write-Verbose -Message "Validated Outlook container."
    }
    Else {
        Write-Error $Error "Could not validate Outlook containers."
    }
    Write-Verbose -Message "Applying security permissions for $($User.samAccountName)."
    Try {
        If ($pscmdlet.ShouldProcess($User.samAccountName, "Add permissions")) {
            Add-FslPermissions -User $User.samAccountName -folder $Directory
        }
        Write-Verbose -Message "Successfully applied security permissions for $($User.samAccountName)."
    }
    Catch {
        Write-Warning -Message "Error Code: $(Get-LineNumber)"
        Write-Error $Error[0]
        Exit
    }

    Write-Verbose -Message "Gather OST data file path."
    If ($DataFilePath.ToLower().Contains("%username%")) {
        $userOldOst = $DataFilePath -replace "%username%", $User.samAccountName
    }
    Else {
        $userOldOst = Join-Path $DataFilePath $User.samAccountName
    }
    If (-not(Test-Path -Path $userOldOst)) {
        Write-Warning -Message "Invalid OST path: $userOldOst"
        Write-Warning -Message "Error Code: $(Get-LineNumber)"
        Write-Error "Could not locate OST file for $($User.samAccountName)."
        Exit
    }
    Else {
        $dataFiles = Get-ChildItem -Path $userOldOst -Filter $FileType -Recurse
    }
    If ($Null -eq $dataFiles) {
        Write-Warning -Message "No Outlook data files returned in $userOldOst"
        Write-Warning -Message "Error Code: $(Get-LineNumber)"
        Write-Error "Could not locate Outlook data files for $($User.samAccountName)."
        Exit
    }
    Else {
        Write-Verbose -Message "Successfully obtained OST file."
    }

    Write-Verbose -Message "Create junction point."
    Try {
        If ($assignDriveLetter) {
            If ($pscmdlet.ShouldProcess($vhdPath, "Mount")) {
                $MountPath = Add-FslDriveLetter -Path $vhdPath -Passthru
                Write-Verbose -Message "VHD mounted on: $MountPath"
            }
        }
        Else {
            If ($pscmdlet.ShouldProcess($vhdPath, "Mount")) {
                $Mount = Mount-FslDisk -Path $vhdPath -ErrorAction Stop -PassThru
                $MountPath = $Mount.Path
                Write-Verbose -Message "Created junction point: $MountPath"
            }
        }
    }
    Catch {
        Write-Warning -Message "Error Code: $(Get-LineNumber)"
        Write-Error $Error[0]
        Exit
    }

    Write-Verbose -Message "Copy OST File"
    $dataFileDestination = Join-Path $MountPath $ODFCPath
    If (-not (Test-Path -Path $dataFileDestination)) {
        If ($pscmdlet.ShouldProcess($dataFileDestination, "Create")) {
            New-Item -ItemType Directory -Path $dataFileDestination -Force | Out-Null
        }
    }
    ForEach ($dataFile in $dataFiles) {
        Try {
            Write-Verbose -Message "Copy file $($dataFile.FullName) to $ODFCPath."
            If ($pscmdlet.ShouldProcess($dataFile.FullName, "Copy to disk")) {
                Copy-FslToDisk -VHD $vhdPath -Path $dataFile.FullName -Destination $ODFCPath -ErrorAction Stop
            }
        }
        Catch {
            Dismount-FslDisk -Path $vhdPath
            Write-Warning -Message "Error Code: $(Get-LineNumber)"
            Write-Error $Error[0]
            Exit
        }
    }

    If ($renameOldDataFile) {
        ForEach ($dataFile in $dataFiles) {
            Try {
                If ($pscmdlet.ShouldProcess($dataFile.FullName, "Rename")) {
                    Write-Verbose -Message "Rename [$($dataFile.FullName)] to [$($dataFile.BaseName).old]."
                    Rename-Item -Path $dataFile.FullName -NewName "$($dataFile.BaseName).old" -Force -ErrorAction Stop
                }
            }
            Catch {
                Write-Warning -Message "Error Code: $(Get-LineNumber)"
                Write-Error $Error[0]
                Exit
            }
        }
    }
    If ($renameOldDirectory) {
        Try {
            Write-Verbose -Message "Renaming old Outlook data file directory"
            If ($pscmdlet.ShouldProcess($userOldOst, "Rename")) {
                Rename-Item -Path $userOldOst -NewName "$($userOldOst)_Old" -Force -ErrorAction Stop
            }
        }
        Catch {
            Write-Warning -Message "Error Code: $(Get-LineNumber)"
            Write-Error $Error[0]
            Exit
        }
        Write-Verbose -Message "Successfully renamed old Outlook data file directory"
    }
    If ($removeFromAD) {
        Try {
            Write-Verbose -Message "Removing $($User.samAccountName) from AD group: $Group."
            If ($pscmdlet.ShouldProcess($User.samAccountName, "Remove from group")) {
                Remove-ADGroupMember -Identity $Group -Members $User.samAccountName -ErrorAction Stop
            }
        }
        Catch {
            Write-Warning -Message "Error Code: $(Get-LineNumber)"
            Write-Error $Error[0]
            Exit
        }
        Write-Verbose -Message "Successfully removed $($User.samAccountName) from AdGroup: $Group."
    }

    Write-Verbose -Message "Successfully migrated OST file for $($User.samAccountName). Dismounting VHD."
    Try {
        If ($pscmdlet.ShouldProcess($vhdPath, "Dismount")) {
            Dismount-FslDisk -Path $vhdPath -ErrorAction Stop
            Write-Verbose -Message "Dismounted VHD."
        }
    }
    Catch {
        Write-Warning -Message "Error Code: $(Get-LineNumber)"
        Write-Error $Error[0]
        Exit
    }
}
#endregion
