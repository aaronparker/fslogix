function Get-FslDisk {
    <#
        .SYNOPSIS
        Retrives a virtual disk's information.

        .DESCRIPTION
        Retrieves either a virtual disk's information or a collection
        of virtual disks within a folder.

        .PARAMETER Path
        Path to a specified Virtual disk

        .PARAMETER Folder
        Path to a specified directory containing virtual disks

        .EXAMPLE
        Get-FslDisk -path "C:\Tests\VHD\test.vhd"
        Retrives VHD: Test.vhd and returns informational output

        .EXAMPLE
        Get-FslDisk -folder "C:\tests\vhdFolder"
        Retrieves all the VHD's in folder: vhdFolder and returns their information.
    #>
    [CmdletBinding(DefaultParameterSetName = "Path")]
    param (
        [Parameter( Position = 0,
                    Mandatory = $true,
                    ValueFromPipeline = $true,
                    ValueFromPipelineByPropertyName = $true,
                    ParameterSetName = "Path")]
        [System.String]$Path,

        [Parameter( Position = 1,
                    Mandatory = $true,
                    ValueFromPipeline = $true,
                    ValueFromPipelineByPropertyName = $true,
                    ParameterSetName = "Folder")]
        [System.String]$Folder
    )
    
    begin {
        Set-StrictMode -Version Latest
        #Requires -RunAsAdministrator
    }
    
    Process {
        Switch ($PSCmdlet.ParameterSetName){
            Path {
                if(-not(test-path -path $Path)){
                    Write-Error "Could not find path: $Path" -ErrorAction Stop
                }
                $VHD_Info = Get-DiskInformation -Path $Path
            }
            Folder {
                if( -not (test-path -path $Folder)){
                    Write-Error "Could not find directory: $Folder" -ErrorAction Stop
                }

                $VHDs_Info = Get-Childitem -path $Folder -Recurse -Filter "*.vhd*"
                $VHD_Info = foreach($Vhd in $VHDs_Info){
                    $VHD.FullName | Get-DiskInformation
                }
            }
        }
        $VHD_Info
    }
    
    end {
    }
}