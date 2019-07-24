function Add-FslPermissions {
    [CmdletBinding(DefaultParameterSetName = 'File')]
    param (
        [Parameter( Position = 0,
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [System.String]$User,

        [Parameter( Position = 1,
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'File')]
        [System.String]$File,

        [Parameter( Position = 2,
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'Folder')]
        [System.String]$Folder,

        [Parameter(ParameterSetName = 'Folder')]
        [Switch]$Inherit,

        [Parameter (ValueFromPipelineByPropertyName = $true)]
        [ValidateSet("ListDirectory", "ReadData", "WriteData", "CreateFiles", "CreateDirectories", 
            "AppendData", "ReadExtendedAttributes", "WriteExtendedAttributes", 
            "Traverse", "ExecuteFile", "DeleteSubdirectoriesAndFiles", "ReadAttributes",
            "WriteAttributes", "Write", "Delete", "ReadPermissions", "Read", "ReadAndExecute", "Modify", 
            "ChangePermissions", "TakeOwnership", "Synchronize", "FullControl")]
        [System.String[]]$PermissionType = @('CreateDirectories', 'ListDirectory', 'AppendData', 'Traverse', 'ReadAttributes'),

        [Parameter (ValueFromPipelineByPropertyName = $true)]
        [ValidateSet("Allow", "Deny")]
        [System.String]$Permission = "Allow"
    )
    
    begin {
        Set-StrictMode -Version Latest
        #Requires -RunAsAdministrator
        #Requires -Modules "ActiveDirectory"
    }
    
    process {

        Try {
            $AdUser = Get-ADUser $User -ErrorAction Stop | Select-Object -ExpandProperty SamAccountName
        }
        Catch {
            Write-Error $Error[0]
        }

        if (!$PSBoundParameters.ContainsKey("PermissionType")) {
            $PermissionType = "FullControl"
        }
        if (!$PSBoundParameters.ContainsKey("Permission")) {
            $Permission = "Allow"
        }

        $PermissionType = $PermissionType | Get-Unique

        Switch ($PSCmdlet.ParameterSetName) {
            File {
                if (-not(Test-Path -path $file)) {
                    Write-Error "Could not find path: $File" -ErrorAction Stop
                }
                else {
                    $FileisFile = Get-Item -path $file
                    if ($FileisFile.Attributes -ne "Archive") {
                        Write-Error "$($FileisFile.BaseName) is not a file." -ErrorAction Stop
                    }
                }

                Try {
                    $Acl = Get-Acl $File
                    $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule($AdUser, $PermissionType, $Permission)
                    $Acl.Setaccessrule($Ar)
                    Set-Acl -Path $File $Acl
                    Write-Verbose "Assigned permissions for user: $AdUser"
                }
                catch {
                    Write-Error $Error[0]
                }
            }

            Folder {
                if (-not(Test-Path -path $folder)) {
                    Write-Error "Could not find path: $Folder" -ErrorAction Stop
                }
                
                $FolderisFolder = Get-Item -path $Folder
                if ($FolderisFolder.Attributes -ne 'Directory') {
                    Write-Error "$($FolderisFolder.BaseName) is not a folder." -ErrorAction Stop
                }
                
                $Dir = $FolderisFolder.FullName

                $PermissionType = @("ListDirectory", "ReadData", "WriteData", "CreateFiles", "CreateDirectories", 
                    "AppendData", "ReadExtendedAttributes", "WriteExtendedAttributes", 
                    "Traverse", "ExecuteFile", "DeleteSubdirectoriesAndFiles", "ReadAttributes",
                    "WriteAttributes", "Write", "Delete", "ReadPermissions", "Read", "ReadAndExecute", "Modify", 
                    "ChangePermissions", "TakeOwnership", "Synchronize", "FullControl")
                
                Try {
                    $ACL = Get-Acl $Dir
                    if ($PSBoundParameters.ContainsKey("Inherit")) {
                        $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule($AdUser, $PermissionType, "ContainerInherit, ObjectInherit", "None", $Permission)
                    }
                    else {
                        $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule($AdUser, $PermissionType, "None", "none" , $Permission)
                    }
                    $Acl.Setaccessrule($Ar)
                    Set-Acl -Path $Dir $ACL
                    Write-Verbose "Assigned permissions for user: $AdUser"
                }
                catch {
                    Write-Error $Error[0]
                }
                
            }#folder
        }#switch
    }#process
}
