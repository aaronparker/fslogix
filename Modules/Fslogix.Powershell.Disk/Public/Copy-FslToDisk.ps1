function Copy-FslToDisk {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [System.String]$VHD,

        [Parameter(Position = 1, Mandatory = $true)]
        [System.String[]]$Path,

        [Parameter(Position = 2)]
        [System.String]$Destination,

        [Parameter(Position = 3)]
        [Switch]$Dismount,

        [Parameter(Position = 4)]
        [System.String]$CopyLog = (Join-Path -Path $PWD -ChildPath "$($MyInvocation.MyCommand).log"),

        [Parameter(Position = 5)]
        [Switch]$CheckSpace
    )
    
    begin {
        Set-StrictMode -Version Latest
        #Requires -RunAsAdministrator
    }
    
    process {
        Try {
            $MountedDisk = Mount-FslDisk -Path $VHD -PassThru -ErrorAction Stop
        }
        Catch {
            Write-Error $Error[0]
            exit
        }
        $MountedPath = $MountedDisk.Path
        $DiskNumber = $MountedDisk.disknumber
        $PartitionNumber = $MountedDisk.PartitionNumber
        
        $CopyDestination = Join-Path ($MountedPath) ($Destination)
    
        if (-not(Test-Path -path $CopyDestination)) {
            New-Item -ItemType Directory $CopyDestination -Force -ErrorAction SilentlyContinue | Out-Null
        }

        if ($PSBoundParameters.ContainsKey("CheckSpace")) {
            $Partition = Get-Partition -disknumber $DiskNumber -PartitionNumber $PartitionNumber
            $FreeSpace = get-volume -Partition $Partition | Select-Object -expandproperty SizeRemaining
            $Size = Get-FslSize -path $Path
            if ($Size -ge $FreeSpace) {
                Write-Warning "Contents: $([Math]::round($Size/1mb,2)) MB. Disk free space is: $([Math]::round($Freespace/1mb,2)) MB."
                Write-Error "Disk is too small to copy contents over." -ErrorAction Stop
            }
        }
        
        
        Try {
            foreach ($file in $Path) {
                ## Using Robocopy to copy permissions.
                $fileName = Split-Path -Path $file -Leaf
                $filePath = Split-Path -Path $file -Parent
                $Command = "robocopy $filePath $CopyDestination $fileName /S /NJH /NJS /NDL /NP /FP /W:0 /R:0 /XJ /SEC /COPYALL /LOG+:$($CopyLog)"
                Invoke-Expression $Command 

                # Invoke-Process parameters
                <#$invokeProcessParams = @{
                    FilePath     = "$env:SystemRoot\System32\robocopy.exe"
                    ArgumentList = "$filePath $CopyDestination $fileName /S /NJH /NJS /NDL /NP /FP /W:0 /R:0 /XJ /SEC /COPYALL /LOG+:$($CopyLog)"
                }
                Invoke-Process @invokeProcessParams#>
            }
            Write-Verbose "Copied $filePath to $CopyDestination."
        }
        catch {
            Dismount-FslDisk -DiskNumber $DiskNumber
            Write-Error $Error[0]
            exit
        }

        if ($Dismount) {
            Try {
                Dismount-FslDisk -DiskNumber $DiskNumber
            }
            catch {
                Write-Error $Error[0]
            }
        }
    }
    
    end {
    }
}