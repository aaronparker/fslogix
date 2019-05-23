function Remove-FslDriveLetter {
    [CmdletBinding()]
    param (
        [Parameter( Position = 0, 
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [System.String]$Path,

        [Parameter (Position = 1)]
        [Switch]$Dismount,

        [Parameter (Position = 2)]
        [int]$PartitionNumber
    )

    begin {
        Set-StrictMode -Version Latest
        #Requires -RunAsAdministrator
    }

    process {

        if (-not(test-path -path $path)) {
            Write-Error "Could not find path: $path" -ErrorAction Stop
        }
        if(!$PSBoundParameters.ContainsKey("PartitionNumber")){
            # FsLogix's VHD partition Number defaulted to 1.
            $PartitionNumber = 1
        }
        $VHD = Get-FslDisk -path $Path

    
        ## Need to mount ##
        if ($vhd.attached) {
            $mount = get-disk | Where-Object {$_.Location -eq $Path}
        }
        else {
            Try {
                $mount = Mount-DiskImage -ImagePath $Path -Passthru -ErrorAction Stop | get-diskimage -ErrorAction Stop
            }
            catch {
                write-error $Error[0]
            }
        }
        
       
        $DiskNumber = $Mount.Number
        $driveLetter = Get-partition -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber | Select-Object -ExpandProperty AccessPaths | Select-Object -first 1

        if ($null -eq $driveLetter) {
            Write-Error "Drive Letter is already removed for $Path"
            exit
        }
        if ($driveLetter.length -ne 3) {
            Write-Error "No valid drive letter found for $Path."
            exit
        }

        $DL = $Driveletter.substring(0, 1)

        try {
            $Volume = Get-Volume | where-Object {$_.DriveLetter -eq $DL}
        }
        catch {
            Write-Error $Error[0]
        }
        try {
            $Volume | Get-Partition | Remove-PartitionAccessPath -AccessPath $Driveletter -ErrorAction Stop
            Write-Verbose "$(Get-Date): Successfully removed $Driveletter"
        }
        catch {
            Write-Error $Error[0]
            exit
        }
            
        if ($Dismount) {
            try {
                Dismount-DiskImage -ImagePath $Path
            }
            catch {
                Write-Error $Error[0]
            }
        }
    }

    end {
    }
}