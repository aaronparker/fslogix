function Get-FslDriveLetter {
    [CmdletBinding()]
    param (
        [Parameter (Position = 0,
                    Mandatory = $true,
                    ValueFromPipeline = $true,
                    ValueFromPipelineByPropertyName = $true)]
        [System.String]$Path,

        [Parameter (Position = 1)]
        [Switch]$Dismount
    )
    
    begin {
        Set-StrictMode -Version Latest
        #Requires -RunAsAdministrator
    }
    
    process {

        if(-not(test-path -path $Path)){
            Write-Error "Could not find path: $Path." -ErrorAction Stop
        }

        $VHD = Get-FslDisk -path $Path
        if($VHD.Attached){
            $mount = Get-Disk | Where-Object {$_.Location -eq $Path}
        }else{
            Try{
                $Mount = Mount-DiskImage -ImagePath $Path -PassThru -ErrorAction Stop | Get-DiskImage -ErrorAction Stop
            }catch{
                Write-Error $Error[0]
            }
        }

        $DiskNumber = $mount.Number
        $DriveLetter = Get-Partition -DiskNumber $DiskNumber | Select-Object -ExpandProperty AccessPaths | select-object -first 1
        
        if ($null -eq $DriveLetter -or $DriveLetter.length -ne 3) {
            Write-Warning "No valid driveletter found for $($VHD.name)."
        }

        if($Dismount){
            try{
                Dismount-DiskImage -ImagePath $Path
            }catch{
                Write-Error $Error[0]
            }
        }
    }
}