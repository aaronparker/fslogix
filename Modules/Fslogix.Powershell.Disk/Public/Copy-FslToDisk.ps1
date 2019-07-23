Function Copy-FslToDisk {
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, Mandatory = $true)]
        [System.String] $VHD,

        [Parameter(Position = 1, Mandatory = $true)]
        [System.String[]] $Path,

        [Parameter(Position = 2)]
        [System.String] $Destination,

        [Parameter(Position = 3)]
        [System.Management.Automation.SwitchParameter] $Dismount,

        [Parameter(Position = 4)]
        [System.String] $CopyLog = (Join-Path -Path $PWD -ChildPath "$($MyInvocation.MyCommand).log"),

        [Parameter(Position = 5)]
        [System.Management.Automation.SwitchParameter] $CheckSpace
    )
    
    Begin {
        Set-StrictMode -Version Latest
        #Requires -RunAsAdministrator
    }
    Process {
        Try {
            $MountedDisk = Mount-FslDisk -Path $VHD -PassThru -ErrorAction Stop
        }
        Catch {
            Write-Error $Error[0]
            Exit
        }
        $MountedPath = $MountedDisk.Path
        $DiskNumber = $MountedDisk.DiskNumber
        $PartitionNumber = $MountedDisk.PartitionNumber
        $CopyDestination = Join-Path ($MountedPath) ($Destination)
    
        If (-not(Test-Path -path $CopyDestination)) {
            New-Item -ItemType Directory $CopyDestination -Force -ErrorAction SilentlyContinue | Out-Null
        }

        If ($PSBoundParameters.ContainsKey("CheckSpace")) {
            $Partition = Get-Partition -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber
            $FreeSpace = get-volume -Partition $Partition | Select-Object -ExpandProperty SizeRemaining
            $Size = Get-FslSize -Path $Path
            If ($Size -ge $FreeSpace) {
                Write-Warning "Contents: $([Math]::round($Size/1mb,2)) MB. Disk free space is: $([Math]::round($Freespace/1mb,2)) MB."
                Write-Error "Disk is too small to copy contents over." -ErrorAction Stop
            }
        }
        
        Try {
            ForEach ($file in $Path) {
                ## Using Robocopy to copy permissions.
                $fileName = Split-Path -Path $file -Leaf
                $filePath = Split-Path -Path $file -Parent
                $Command = "robocopy `"$filePath`" `"$CopyDestination`" `"$fileName`" /S /NJH /NJS /NDL /NP /FP /W:0 /R:0 /XJ /LOG+:$($CopyLog)"
                # $Command = "robocopy `"$filePath`" `"$CopyDestination`" `"$fileName`" /S /NJH /NJS /NDL /NP /FP /W:0 /R:0 /XJ /SEC /COPYALL /LOG+:$($CopyLog)"
                Invoke-Expression $Command 
            }
            Write-Verbose "Copied $filePath to $CopyDestination."
        }
        Catch {
            Dismount-FslDisk -DiskNumber $DiskNumber
            Write-Error $Error[0]
            Exit
        }

        If ($Dismount) {
            Try {
                Dismount-FslDisk -DiskNumber $DiskNumber
            }
            Catch {
                Write-Error $Error[0]
            }
        }
    }
    End {
    }
}
