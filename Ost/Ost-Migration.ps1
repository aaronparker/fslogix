##
## REQUIRES FsLogix.PowerShell.Disk to be installed
## https://github.com/FSLogix
##

## MANDATORY VARIABLES - USER WILL NEED TO CHANGE ##
$Vhd_Size_InMB = 30000                                 #VHD Size (In MB)
$AdGroup = "Citrix Migrate OST FSLogix VHDX"     #Name of Active Directory Group
$Old_OST_Location = "\\mailcache\ost\%username%"          #Location of the ost files
$New_OST_Location = "ODFC"                                #Destination for Ost files within VHD
$FsLogix_VHDLocation = "\\mailcache\ost\fslogix\%username%"  #Location of FsLogix VHD

## OPTIONAL VARIABLES - USER DOESN'T NEED TO CHANGE ##
$ComputerName = $Env:COMPUTERNAME             #User's computername
$Vhd_isDynamic = 1                             #1 = dynamic, 0 = fixed
$VerbosePreference = "continue"                    #continue for output, silentlycontinue for no output
$Rename_Old_Ost = $false                        #true to rename old ost with .old extension, false to leave old ost the same
$Rename_Old_Directory = $true                         #true to rename old directory to include _old, false to leave old directory the same
$Remove_FromAD = $true                         #true to remove AD User after sucessful migration, false to keep AD user
$FlipFlop = $false                        #true to have directory name SID_Name, false to have directory name Name_SID
$AssignDriveLetter = $false                        #true to initialize driveletter, false to mount to path


### David Young's Notes ###

#old location is currently \\mailcache\ost\%username%
#vhdx location is \\mailcache\ost\fslogix\%username%
#need file format
#after complete rename ost to to .old extension if possible and rename directory of user to _old
#we are using vhdx not vhd for files
#Dave request can this be made to read AD group
#if success can it remove user from ad group and only leave unmigrated users for another attempt of job run
#file name string is set to username - sid


## Start of Script ##
Set-StrictMode -Version Latest
#Requires -RunAsAdministrator
#Requires -Modules "ActiveDirectory"
Function GetLineNumber() {
    $MyInvocation.ScriptLineNumber
}

## Validate Frx.exe is installed.
Try {
    $FrxPath = Confirm-Frx -Passthru -ErrorAction Stop
}
catch {
    Write-Warning "Error Code: $(GetLineNumber)"
    Write-Error $Error[0]
    exit
}

Set-Location -path (Split-Path -Path $FrxPath -Parent)

Try {
    $AdGroup_Members = Get-AdGroupmember -Identity $AdGroup -Recursive -ErrorAction Stop
}
catch {
    Write-Warning "Error Code: $(GetLineNumber)"
    Write-Error $Error[0]
}

foreach ($User in $AdGroup_Members) {

    Try {
        $Name = $User.Name
        $SID = $User.SID
        $SamAccountName = $User.SamAccountName
        $Label = $SamAccountName
        Write-Verbose "Current User: $Name."
    }
    catch {
        Write-Warning "Error Code: $(GetLineNumber)"
        Write-Error $Error[0]
        exit
    }

    Write-Verbose "Generating $Name's Directory."
    Try {
        if ($FlipFlop) {
            $Directory = New-FslDirectory -SamAccountName $SamAccountName -SID $SID -Destination $FsLogix_VHDLocation -FlipFlop -Passthru -ErrorAction Stop
        }
        else {
            $Directory = New-FslDirectory -SamAccountName $SamAccountName -SID $SID -Destination $FsLogix_VHDLocation -Passthru -ErrorAction Stop
        }
        Write-Verbose "Generated Directory: $Directory"
    }
    catch {
        Write-Warning "Error Code: $(GetLineNumber)"
        Write-Error $Error[0]
        exit
    }

    Write-Verbose "Creating New Virtual Hard Disk"
    $VHD_Name = "ODFC_" + $SamAccountName + ".vhdx"
    $VHD_Path = Join-path ($Directory) ($VHD_Name)
    if (test-path -path $VHD_Path) {
        Remove-item -path $VHD_Path -Force -ErrorAction SilentlyContinue
    }
    Try {
        Invoke-Expression -Command " .\frx.exe create-vhd -filename $VHD_Path -size-mbs=$VHD_Size_InMB -dynamic=$VHD_isDynamic -label $Label"
        Write-Verbose "Created New Virtual Hard Disk."
        Write-Verbose "Generated at: $VHD_Path"
    }
    catch {
        Write-Warning "Error Code: $(GetLineNumber)"
        Write-Error $Error[0]
        exit
    }

    Write-Verbose "Validating FsLogix's outlook container."
    $FslPath = $FsLogix_VHDLocation.TrimEnd('\%username%')
    if ($FlipFlop) {
        $IsFslProfile = Confirm-FslProfile -Path $FslPath -SamAccountName $SamAccountName -SID $SID -FlipFlop
    }
    else {
        $IsFslProfile = Confirm-FslProfile -Path $FslPath -SamAccountName $SamAccountName -SID $SID
    }
    if ($IsFslProfile) {
        Write-Verbose "Validated FsLogix outlook containers."
    }
    else {
        Write-Error $Error "Could not validate FsLogix outlook containers."
    }
    Write-Verbose "Applying security permissions for $Name."
    Try {
        Add-FslPermissions -User $Name -folder $Directory
        Write-Verbose "Successfully applied security permissions for $name."
    }
    catch {
        Write-Warning "Error Code: $(GetLineNumber)"
        Write-Error $Error[0]
        exit
    }

    Write-Verbose "Obtaining OST File."
    if ($Old_OST_Location.ToLower().Contains("%username%")) {
        $User_OldOst = $Old_OST_Location -replace "%Username%", $SamAccountName
    }
    else {
        $User_OldOst = Join-Path ($Old_OST_Location) ($SamAccountName)
    }
    if (-not(test-path -path $User_OldOst)) {
        Write-Warning "Invalid old ost path: $User_Oldost"
        Write-Warning "Error Code: $(GetLineNumber)"
        Write-Error "Could not find old ost path for $Name."
        exit
    }
    else {
        $OST = Get-childitem -path $User_OldOst -Filter "*.ost" -Recurse
    }
    if ($Null -eq $OST) {
        Write-Warning "Could not find ost file in $User_Oldost"
        Write-Warning "Error Code: $(GetLineNumber)"
        Write-Error "Did not find ost file." 
        exit
    }
    else {
        Write-Verbose "Obtained ost file."
    }

    Write-Verbose "Creating Junction point."
    Try {
        if ($AssignDriveLetter) {
            $MountPath = Add-FslDriveLetter -Path $VHD_Path -Passthru
            Write-Verbose "VHD mounted on: $MountPath"
        }
        else {
            $Mount = Mount-FslDisk -Path $VHD_Path -ErrorAction Stop -PassThru
            $MountPath = $Mount.Path
            Write-Verbose "Created Junction Point: $MountPath"
        }
        
    }
    Catch {
        Write-Warning "Error Code: $(GetLineNumber)"
        Write-Error $Error[0]
        exit
    }

    Write-Verbose "Copying Ost File"
    $Ost_Destination = Join-Path ($MountPath) ($New_OST_Location)
    if (-not (Test-path -Path $Ost_Destination)) {
        New-Item -ItemType Directory -Path $Ost_Destination -Force | out-null
    }
    Try {
        Copy-FslToDisk -VHD $VHD_Path -Path $OST.FullName -Destination $New_OST_Location -ErrorAction Stop
    }
    catch {
        Dismount-FslDisk -Path $VHD_Path
        Write-Warning "Error Code: $(GetLineNumber)"
        Write-Error $Error[0]
        exit
    }

    <#

    Copy-FslToDisk copies using robocopy with /copyall parameter, so permissions are
    Carried over.

    Write-Verbose "Applying Permissions to ost files"
    Try{
        Add-FslPermissions -User $Name -folder $Ost_Destination -Recurse -Full
        Write-Verbose "Successfully applied security permissions for ost files."
    }catch{
        Dismount-FslDisk -Path $VHD_Path
        Write-Warning "Error Code: $(GetLineNumber)"
        Write-Error $Error[0]
        exit
    }#>

    if ($Rename_Old_Ost) {
        Try {
            Write-Verbose "Renaming old ost files to .old extension"
            Rename-item -path $OST.FullName -NewName "$($OST.basename).old" -Force -ErrorAction Stop
            Write-Verbose "Successfully renamed old ost files."
        }
        catch {
            Write-Warning "Error Code: $(GetLineNumber)"
            Write-Error $Error[0]
            exit
        }
    }
    if ($Rename_Old_Directory) {
        Try {
            Write-Verbose "Renaming old ost directory"
            Rename-item -path $User_OldOst -NewName "$($User_oldost)_Old" -Force -ErrorAction Stop
            Write-Verbose "Successfully renamed old ost directory"
        }
        catch {
            Write-Warning "Error Code: $(GetLineNumber)"
            Write-Error $Error[0]
            exit
        }
    }
    if ($Remove_FromAD) {
        Try {
            Write-Verbose "Removing $Name from AdGroup: $AdGroup."
            Remove-ADGroupMember -Identity $AdGroup -Members $SamAccountName -ErrorAction Stop
            Write-Verbose "Successfully removed $Name from AdGroup: $AdGroup."
        }
        catch {
            Write-Warning "Error Code: $(GetLineNumber)"
            Write-Error $Error[0]
            exit
        }
    }

    Write-Verbose "Successfully migrated ost file for $name. Dismounting VHD."
    Try {
        Dismount-FslDisk -Path $VHD_Path -ErrorAction Stop
        Write-Verbose "Dismounted VHD."
    }
    catch {
        Write-Warning "Error Code: $(GetLineNumber)"
        Write-Error $Error[0]
        exit
    }
} # foreach