function Mount-FslDisk {
    <#
        
    #>

    param(
        [Parameter( Position = 0, 
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]$Path,

        [Parameter (Position = 1)]
        [Alias("Partition")]
        [int]$PartitionNumber,
        
        [Parameter( Position = 2 )]
        [Switch]$PassThru,

        [Switch]$AsString

    )
    begin {
        Set-StrictMode -Version Latest
        #Requires -RunAsAdministrator
    }
    process {

        if (-not(test-path -path $Path)) {
            Write-Error "Could not find path: $Path" -ErrorAction Stop
        }
        $VHD = get-Fsldisk -path $Path
        if ($VHD.attached) {
            $mount = get-disk -Number $VHD.Number
        }
        else {

            Try {
                $mount = Mount-DiskImage -ImagePath $Path -PassThru -ErrorAction Stop | Get-DiskImage -ErrorAction Stop
            }
            catch {
                Write-Error $Error[0]
                exit
            }
        }

        $Name = $VHD.basename
        $DiskNumber = $mount.Number
        $GuidPath = "C:\programdata\fslogix\Guid"

        if(!$PSBoundParameters.ContainsKey("PartitionNumber")){
            $PartitionNumber = 1
        }

        Try {
            $DriveLetter = Get-Partition -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber -ErrorAction Stop | Select-Object -ExpandProperty AccessPaths | select-object -first 1
        }
        catch {
            Dismount-DiskImage -ImagePath $Path -ErrorAction SilentlyContinue
            Write-Error $Error[0]
            exit
        }
      
        if (($null -eq $DriveLetter) -or ($driveLetter -like "*\\?\Volume{*")) {
            
            Write-Verbose "$(Get-Date): Did not receive valid driveletter: [$Driveletter]. Assigning temporary junction point."
            $Guid = (New-Guid).Guid
            $JunctionPath = Join-path ($GuidPath) ($Guid)

            if (test-path -path $JunctionPath) {
                Remove-Item -path $JunctionPath -Force -ErrorAction SilentlyContinue
            }

            Try {
                New-Item -Path $JunctionPath -ItemType Directory -ErrorAction Stop| Out-Null
            }
            catch {
                Write-Warning "Could not create junction path."
                Remove-Item -path $JunctionPath -Force -ErrorAction SilentlyContinue
                Dismount-DiskImage -ImagePath $Path -ErrorAction SilentlyContinue
                Write-Error $Error[0]
                exit
            }
            
            Try {
                ## FsLogix's VHD main partition is 1
                Add-PartitionAccessPath -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber -AccessPath $JunctionPath -ErrorAction Stop
            }
            catch {
                Write-Warning "Could not assign AccessPath. Perhaps you're not using a FsLogix VHD?"
                Remove-Item -path $JunctionPath -Force -ErrorAction SilentlyContinue
                Dismount-DiskImage -ImagePath $Path -ErrorAction SilentlyContinue
                Write-Error $Error[0]
                exit
            }
            
            $DriveLetter = $JunctionPath
        }
        
        if ($DriveLetter.Length -eq 3) {
            Write-Verbose "$(Get-Date): $Name mounted on Drive Letter [$Driveletter]."
        }
        else {
            Write-Verbose "$(Get-Date): $Name mounted on Drive junction point [$DriveLetter]."
        }

        if ($PSBoundParameters.ContainsKey("Passthru")) {
            
            if($PSBoundParameters.ContainsKey("AsString")){
                [System.String]$DiskNumber = $DiskNumber
                [System.String]$DriveLetter = $DriveLetter
                [System.String]$PartitionNumber = $PartitionNumber
            }

            $Output = [PSCustomObject]@{
                DiskNumber      = $DiskNumber
                Path            = $DriveLetter
                PartitionNumber = $PartitionNumber
            }
            $Output
        }
    }
}