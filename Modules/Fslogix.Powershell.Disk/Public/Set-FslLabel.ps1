function Set-FslLabel {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param (
        [Parameter (Position = 0,
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'Path')]
        [ValidateNotNullOrEmpty()]
        [System.String]$Path,

        [Parameter (Position = 0,
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'Number')]
        [int]$DiskNumber,

        [Parameter (Position = 1,
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'Number')]
        [int]$PartitionNumber,

        [Parameter (Position = 1, Mandatory = $true, ParameterSetName = 'Path')]
        [Parameter (Position = 2, Mandatory = $true, ParameterSetName = 'Number')]
        [ValidateNotNullOrEmpty()]
        [System.String]$Label,

        [switch]$Dismount
    )
    
    begin {
        #Requires -RunAsAdministrator
        #Requires -Modules "ActiveDirectory"
    }
    process {
        
        if($PSBoundParameters.ContainsKey("Path")){
            Try{
                $Mount              = Mount-fsldisk -Path $Path -PassThru -ErrorAction Stop
                $DiskNumber         = $Mount.DiskNumber
                $PartitionNumber    = $Mount.PartitionNumber
            }catch{
                Write-Error $Error[0]
            }
        }
        Try{
            $Partition = Get-Partition -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber -ErrorAction Stop
        }catch{
            Write-Error $Error[0]
        }
        Try{
            $Volume = Get-Volume -Partition $Partition -ErrorAction Stop
            set-Volume -InputObject $Volume -NewFileSystemLabel $Label
            Write-Verbose "Successfully set disk Label: $Label."
        }catch{
            Write-Error $Error[0]
        }
        if($PSBoundParameters.ContainsKey("Dismount")){
            Switch($PSCmdlet.ParameterSetName){
                Path{
                    Try{
                        Dismount-fsldisk -Path $Path -ErrorAction Stop
                    }catch{
                        Write-Error $Error[0]
                    }
                }
                Number{
                    Try{
                        Dismount-fsldisk -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber -ErrorAction Stop
                    }catch{
                        Write-Error $Error[0]
                    }
                }
            }
            
        }
    }
    
    end {
    }
}