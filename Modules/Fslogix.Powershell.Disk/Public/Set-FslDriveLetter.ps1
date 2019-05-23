function Set-FslDriveLetter {
    [CmdletBinding()]
    param (
        [Parameter( Position = 0, 
                    Mandatory = $true, 
                    ValueFromPipeline = $true,
                    ValueFromPipelineByPropertyName = $true)]
        [System.String]$Path,

        [Parameter( Position = 1, 
                    Mandatory = $true, 
                    ValueFromPipeline = $true,
                    ValueFromPipelineByPropertyName = $true)]
        [ValidatePattern('^[a-zA-Z]')]
        [System.Char]$Letter,

        [Parameter (Position = 2)]
        [int]$PartitionNumber,

        [Parameter( Position = 3)]
        [Switch]$Dismount
    )

    begin {
        Set-StrictMode -Version Latest
        #Requires -RunAsAdministrator
    }

    process {

        if(!$PSBoundParameters.ContainsKey("PartitionNumber")){
            $PartitionNumber = 1
        }

        if (-not(test-path -path $Path)) {
            Write-Error "Could not find path: $Path" -ErrorAction Stop
        }

        $VHDs = Get-FslDisk -path $Path
        if ($null -eq $VHDs) {
            Write-Warning "Could not find any VHD's in path: $Path" -WarningAction Stop
        }

        $AvailableLetters = Get-FslAvailableDriveLetter

        $Available = $false

        if ($AvailableLetters -contains $Letter) {
            $Available = $true
        }

        if ($Available -eq $false) {
            Write-Error "DriveLetter '$($Letter):\' is not available. " -ErrorAction Stop
        }
        $name = $vhds.name
        if ($vhds.attached) {
            $Disk = get-disk | where-object {$_.Location -eq $Path}
        }
        else {
            $mount = Mount-DiskImage -ImagePath $path -NoDriveLetter -PassThru -ErrorAction Stop | get-diskimage
            $Disk = $mount | get-disk -ErrorAction Stop
        }

        $DiskNumber = $disk.Number

        Try{
            $Partition = get-partition -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber
        }catch{
            Write-Error $Error[0]
        }
        $Partition | set-partition -NewDriveLetter $letter -ErrorAction Stop 

        Write-Verbose "Succesfully changed $name's Driveletter to [$($letter):\]."
        
        if ($Dismount) {
            Try {
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