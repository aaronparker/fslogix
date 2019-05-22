function Set-FslDisk {
    <#
        .PARAMETER SIZE
        New size of the VHD. Input is either a number, or xMB, xGB, xTB.
    #>
    [CmdletBinding(DefaultParameterSetName = "None")]
    param (
        [Parameter( Position = 0,
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [System.String]$Path,

        [Parameter (Position = 1,
            Mandatory = $true,
            ParameterSetName = "Label")]
        [System.String]$Label,

        [Parameter (Position = 1,
            Mandatory = $true,
            ParameterSetName = "Name")]
        [System.String]$Name,

        [Parameter (Position = 1,
            Mandatory = $true,
            ParameterSetName = "Size")]
        [uint64]$size,

        [switch]$Dismount,

        [Switch]$Assign
    )
    
    begin {
        Set-Strictmode -Version Latest
        #Requires -RunAsAdministrator
    }
    
    process {

        if (-not(test-path -path $Path -ErrorAction Stop)) {
            Write-Error "Could not find path: $Path" -ErrorAction Stop
        }
       
        $VHDinfo = Get-Fsldisk -Path $Path -ErrorAction Stop
    
        Switch ($PSBoundParameters.Keys) {
            Label {
                Try {
                    Set-FslLabel -Path $Path -Label $Label -ErrorAction Stop
                }
                catch {
                    Write-Error $Error[0]
                }
            }
            Name {
                ## What should the name be. CDW had name of 'ODFC_SamAccountName'
                ## so is the regex match for SID_Name or Name_SID neccessary?
                
                #Can't rename if VHD is attached
                if ($VHDinfo.attached) {
                    Try {
                        Dismount-DiskImage -ImagePath $Path
                    }
                    catch {
                        Write-Error $Error[0]
                    }
                }
                $Extension = $VHDinfo.Extension

                # Using .NET to handle illegal characters, and for multiple dots.
                # Similar PowerShell code would be $Name.Split('.')[1]
                $NewNameExtension = [IO.path]::GetExtension($Name) 
                if([String]::IsNullOrEmpty($NewNameExtension)){
                    $Name = $Name + $Extension
                }
                $NewNameExtension = [IO.path]::GetExtension($Name) 

                if($NewNameExtension -ne $Extension){
                    Write-Error "Extensions must be the same." -ErrorAction Stop
                }
                
                try {
                    Rename-Item -Path $Path -NewName $Name -ErrorAction Stop
                    Write-Verbose "Renamed $($VHDinfo.name) to $Name"
                }
                catch {
                    Write-Warning "Could not rename VHD."
                    Write-Error $Error[0]
                }
            }
            Size {
                #Requires -Modules "Hyper-V"

                Try {
                    Resize-VHD -Path $Path -SizeBytes $size -ErrorAction Stop
                    Write-Verbose "Successfully sized VHD: $($VHDinfo.name)."
                }
                catch {
                    Write-Warning "Could not resize VHD."
                    Write-Error $Error[0]
                    exit
                }

                if ($VHDinfo.attached) {
                    $Disk = Get-Disk | Where-Object {$_.Location -eq $Path}
                    $DiskNumber = $Disk.number
                }
                else {
                    $Disk = Mount-FslDisk -Path $Path
                    $DiskNumber = $Disk.DiskNumber
                }

                
                Try {
                    $PartitionSize = Get-PartitionSupportedSize -DiskNumber $DiskNumber -PartitionNumber 1 -ErrorAction Stop | Select-Object -ExpandProperty Sizemax
                }
                catch {
                    Write-Warning "Could not retrieve supported size max."
                    Write-Error $Error[0]
                    exit
                }
                Try {
                    Resize-Partition -DiskNumber $DiskNumber -PartitionNumber 1 -Size $PartitionSize -ErrorAction Stop
                    Write-Verbose "Successfully reformated partition."
                }
                catch {
                    Write-Warning "Could not reformat partition."
                    Write-Error $Error[0]
                    exit
                }
            }
        } # Switch


        if ($PSBoundParameters.ContainsKey("Assign")) {
            Try {
                Add-FslDriveLetter -Path $Path -ErrorAction Stop
            }
            catch {
                Write-Error $Error[0]
            }
        }

        if ($PSBoundParameters.ContainsKey("Dismount")){
            Try{
                Dismount-FslDisk -Path $Path -ErrorAction Stop
            }catch{
                Write-Warning "Could not dismount VHD."
                Write-Error $Error[0]
            }
        }
    }
    
    end {
    }
}