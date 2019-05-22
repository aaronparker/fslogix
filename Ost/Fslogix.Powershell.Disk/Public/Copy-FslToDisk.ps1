function Copy-FslToDisk {
    [CmdletBinding()]
    param (
        [Parameter( Position = 0,
                    Mandatory = $true,
                    ValueFromPipeline = $true,
                    ValueFromPipelineByPropertyName = $true)]
        [System.String]$VHD,

        [Parameter( Position = 1,
                    Mandatory = $true,
                    ValueFromPipeline = $true,
                    ValueFromPipelineByPropertyName = $true)]
        [System.String[]]$Path,

        [Parameter( Position = 2,
                    ValueFromPipeline = $true,
                    ValueFromPipelineByPropertyName = $true)]
        [System.String]$Destination,

        [Parameter (Position = 3)]
        [Switch]$Dismount,

        [Switch]$CheckSpace
    )
    
    begin {
        Set-StrictMode -Version Latest
        #Requires -RunAsAdministrator
    }
    
    process {
        Try{
            $Mounted_Disk = Mount-FslDisk -Path $VHD -PassThru -ErrorAction Stop
        }Catch{
            Write-Error $Error[0]
            exit
        }
        $Mounted_Path       = $Mounted_Disk.Path
        $Disk_Number        = $Mounted_Disk.disknumber
        $PartitionNumber    = $Mounted_Disk.PartitionNumber
        
        $Copy_Destination = join-path ($Mounted_Path) ($Destination)
    
        if(-not(test-path -path $Copy_Destination)){
            New-Item -ItemType Directory $Copy_Destination -Force -ErrorAction SilentlyContinue | Out-Null
        }

        if($PSBoundParameters.ContainsKey("CheckSpace")){
            $Partition = Get-Partition -disknumber $Disk_Number -PartitionNumber $PartitionNumber
            $FreeSpace = get-volume -Partition $Partition | select-object -expandproperty SizeRemaining
            $Size = Get-FslSize -path $Path
            if($Size -ge $FreeSpace){
                Write-Warning "Contents: $([Math]::round($Size/1mb,2)) MB. Disk free space is: $([Math]::round($Freespace/1mb,2)) MB."
                Write-Error "Disk is too small to copy contents over." -ErrorAction Stop
            }
        }
        
        
        Try{
            foreach($file in $Path){
                ## Using Robocopy to copy permissions.
                $Command = "robocopy $file $Copy_Destination /s /nfl /nc /ns /ndl /w:0 /r:0 /xj /sec /copyall"
                Invoke-Expression $Command 
            }
            Write-Verbose "Successfully copied contents to VHD."
        }catch{
            Dismount-fsldisk -DiskNumber $Disk_Number
            Write-Error $Error[0]
            exit
        }

        if($Dismount){
            Try{
                Dismount-fsldisk -DiskNumber $Disk_Number
            }catch{
                Write-Error $Error[0]
            }
        }
    }
    
    end {
    }
}