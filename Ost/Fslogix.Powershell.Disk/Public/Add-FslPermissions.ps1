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
        [Switch]$inherit,

        [Parameter (ValueFromPipelineByPropertyName = $true)]
        [ValidateSet("ListDirectory", "ReadData", "WriteData", "CreateFiles", "CreateDirectories", 
            "AppendData", "ReadExtendedAttributes", "WriteExtendedAttributes", 
            "Traverse", "ExecuteFile", "DeleteSubdirectoriesAndFiles", "ReadAttributes",
            "WriteAttributes", "Write", "Delete", "ReadPermissions", "Read", "ReadAndExecute", "Modify", 
            "ChangePermissions", "TakeOwnership", "Synchronize", "FullControl")]
        [System.String[]]$PermissionType,

        [Parameter (ValueFromPipelineByPropertyName = $true)]
        [ValidateSet("Allow", "Deny")]
        [System.String]$Permission
    )
    
    begin {
        Set-StrictMode -Version Latest
        #Requires -RunAsAdministrator
        #Requires -Modules "ActiveDirectory"
    }
    
    process {

        Try {
            $Ad_User = Get-ADUser $User -ErrorAction Stop | Select-Object -ExpandProperty SamAccountName
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
                if (-not(test-path -path $file)) {
                    Write-Error "Could not find path: $File" -ErrorAction Stop
                }
                else {
                    $File_isFile = Get-item -path $file
                    if ($File_isFile.Attributes -ne "Archive") {
                        Write-Error "$($File_isFile.BaseName) is not a file." -ErrorAction Stop
                    }
                }

                Try {
                    $ACL = Get-Acl $File
                    $Ar = New-Object system.Security.AccessControl.FileSystemAccessRule($Ad_User, $PermissionType, $Permission)
                    $Acl.Setaccessrule($Ar)
                    Set-Acl -Path $File $ACL
                    Write-Verbose "Assigned permissions for user: $Ad_User"
                }
                catch {
                    Write-Error $Error[0]
                }
            }

            Folder {
                if (-not(test-path -path $folder)) {
                    Write-Error "Could not find path: $Folder" -ErrorAction Stop
                }
                
                $Folder_isFolder = get-item -path $Folder
                if ($Folder_isFolder.Attributes -ne 'Directory') {
                    Write-Error "$($Folder_isFolder.BaseName) is not a folder." -ErrorAction Stop
                }
                
                $Dir = $Folder_isFolder.FullName
                
                Try {
                    $ACL = Get-Acl $dir
                    if ($PSBoundParameters.ContainsKey("inherit")) {
                        $Ar = New-Object system.Security.AccessControl.FileSystemAccessRule($Ad_User, $PermissionType, "ContainerInherit, ObjectInherit", "None", $Permission)
                    }
                    else {
                        $Ar = New-Object system.Security.AccessControl.FileSystemAccessRule($Ad_User, $PermissionType, "None", "none" , $Permission)
                    }
                    $Acl.Setaccessrule($Ar)
                    Set-Acl -Path $dir $ACL
                    Write-Verbose "Assigned permissions for user: $Ad_User"
                }
                catch {
                    Write-Error $Error[0]
                }
                
            }#folder
        }#switch
    }#process
}