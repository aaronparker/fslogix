function Dismount-FslDisk {
    [CmdletBinding(DefaultParameterSetName = "Path")]
    param (
        [Parameter( Position = 0,
                    Mandatory = $true,
                    ValueFromPipelineByPropertyName = $true,
                    ParameterSetName = "Path")]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter( Position = 1,
                    Mandatory = $true,
                    ValueFromPipelineByPropertyName = $true,
                    ParameterSetName = "DiskNumber")]
        [ValidateNotNullOrEmpty()]
        [Alias("Disk")]
        [int]$DiskNumber,

        [Parameter ( Position = 2)]
        [alias("Partition")]
        [int]$PartitionNumber
    )
    
    begin {
        Set-StrictMode -Version Latest
        #Requires -RunAsAdministrator
    }
    
    process {

        if(!$PSBoundParameters.ContainsKey("PartitionNumber")){
            $PartitionNumber = 1
        }

        Switch ($PSCmdlet.ParameterSetName){
            Path {
                if(-not(test-path -path $Path)){
                    Write-Error "Could not find path: $Path." -ErrorAction Stop
                }
                $Disk = Get-Disk | Where-Object {$_.Location -eq $Path}
                if(!$Disk){
                    Write-Error "Could not find disk with path: $Path" -ErrorAction Stop
                }
                $DiskNumber = $Disk.Number
                $Partition = Get-Partition -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber
            }
            DiskNumber {
                $Disk = Get-Disk -Number $DiskNumber
                if(!$Disk){
                    Write-Error "Could not find disk with number: $DiskNumber" -ErrorAction Stop
                }
                $Path = $disk.Location
                Try{
                    Get-FslDisk -path $Path -ErrorAction Stop | out-null
                }catch{
                    Write-Error "DiskNumber: $DiskNumber is not a valid VHD."
                }
                $Partition = Get-Partition -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber
            }
        }

        $Has_JunctionPoint = $Partition | select-object -ExpandProperty AccessPaths | select-object -first 1
        if($Has_JunctionPoint -like "*C:\programdata\fslogix\Guid*"){
      
            Try{
                ## FsLogix's Default VHD partition number is set to 1
                Remove-PartitionAccessPath -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber -AccessPath $Has_JunctionPoint -ErrorAction Stop
            }catch{
                Write-Warning "Could not remove junction point."
                Write-Error $Error[0]
                exit
            }

            Try{
                Remove-Item -Path $Has_JunctionPoint -Force -ErrorAction Stop
            }catch{
                Write-Error $Error[0]
            }
            Write-Verbose "Successfully removed temporary junction point."
        }
        
        try{
            Dismount-DiskImage -ImagePath $Path -ErrorAction Stop
        }catch{
            Write-Warning "Could not dismount disk."
            Write-Error $Error[0]
        }
        
        
    }
    
    end {
    }
}