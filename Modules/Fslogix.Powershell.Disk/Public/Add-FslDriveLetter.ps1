function Add-FslDriveLetter {
    <#
        .SYNOPSIS
        Assigns the next available driveletter starting with Z.

        .DESCRIPTION
        Starting from letter Z, script validates if drive letter is available and assigns
        the partition. If Z is not available, the script will check the next available letter, 'Y',
        and will continue to until completion. If a drive letter is not available then the partition
        will be not set.

        .PARAMETER Path
        Mandatory variable, path to the virtual disk. This path should include the virtual disk with the .vhd/.vhdx extension.
        
        .PARAMETER PartitionNumber
        Non-Mandatory variable, determines specific partitionnumber. FsLogix virtual disk's main partition is assigned
        to partitionnumber 1. If no partitionnumber is assigned, the script will default to 1.

        .PARAMETER Dismount
        Switch parameter is user wants the virtual disk dismounted upon completion, otherwise the virtual disk
        will remain mounted.

        .PARAMETER PassThru
        Switch Parameter to output the drive letter that was assigned to the virtual disk upon completion.
        Output will follow the format of <C:\>

        .EXAMPLE
        Add-FslDriveLetter -path 'C:\test\test.vhdx'
        Script will assign the next available driveletter to virtual disk: test.vhdx

        .EXAMPLE
        Add-FslDriveLetter 'C:\test\test.vhdx'
        Script will accept positional path and assign the next available driveletter.

        .EXAMPLE
        Add-FslDriveLetter 'C:\test\test2.vhdx' -PartitionNumber 2
        Script will assign 
    #>
    [CmdletBinding()]
    param (
        [Parameter( Position = 0,
                    Mandatory = $true,
                    ValueFromPipeline = $true,
                    ValueFromPipelineByPropertyName = $true)]
        [System.String]
        $Path,

        [Parameter (Position = 1,
                    ValueFromPipelineByPropertyName = $true)]
        [int]
        $PartitionNumber,

        [Switch]
        $Dismount,

        [Switch]
        $Passthru
    )
    
    begin {
        Set-StrictMode -Version Latest
        #Requires -RunAsAdministrator
    }
    
    process {

        ## FsLogix VHD's default partition number is 1
        if(!$PSBoundParameters.ContainsKey("PartitionNumber")){
            $PartitionNumber = 1
        }

        $Driveletterassigned = $false
        $Letter = [int][char]'Z'
        $VHD = Get-FslDisk -Path $Path

        if ($Vhd.attached) {
            $Disk = Get-Disk -Number $VHD.Number
        }
        else {
            $Disk = Mount-DiskImage -ImagePath $path -NoDriveLetter -PassThru -ErrorAction Stop | Get-Diskimage
        }

        $DiskNumber = $Disk.Number
        
        while(!$Driveletterassigned){
            Try{
                set-partition -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber -NewDriveLetter $([char]$Letter) -ErrorAction Stop
                $Driveletterassigned = $true
            }catch{
                ## For some reason
                ## $Letter-- won't work.
                $letter = $letter - 1
                if ([char]$Letter -eq 'C') {
                    Write-Warning "Could not assign a drive letter. Is the partition number correct?"
                    Write-Error "Cannot find free drive letter." -ErrorAction Stop
                }
            }
        }
        if ($Driveletterassigned) {
            Write-Verbose "Assigned DriveLetter: $([char]$Letter):\."
        }

        if($Dismount){
            Try{
                Dismount-DiskImage -ImagePath $Path -ErrorAction Stop
            }catch{
                Write-Error $Error[0]
            }
        }

        if($Passthru){
            "$([char]$Letter):\"
        }
    }
    
    end {
    }
}