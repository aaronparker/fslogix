function Get-FslDiskItems {
    [CmdletBinding()]
    param (
        [Parameter( Position = 0,
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true)]
        [System.String]$Path,

        [Parameter( Position = 1,
            ValueFromPipelineByPropertyName = $true)]
        [System.String]$Directory,

        [switch]$Recurse,

        [Switch]$Force,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [String]$Filter,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [String[]]$Include,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [String[]]$Exclude
    )
    
    begin {
        Set-Strictmode -Version Latest
    }
    
    process {
     
        if(-not(test-path -path $Path)){
            Write-Error "Could not find path: $Path"
            exit
        }
        
        Try{
            $Disk = Mount-FslDisk -Path $Path -PassThru -ErrorAction Stop
            $MountPath = $Disk.path
        }Catch{
            Write-Warning "Could not mount VHD"
            Write-Error $Error[0]
        }

        ##
        ## Guid mount paths have a hidden file/dir called 'System Volume Information'.
        ## Access to that is denied which causes errors, but should be fine.
        ## Hidden files/Dir are only found using -force parameter
        ##
        $Command = "Get-Childitem -Path $MountPath"
        switch($PSBoundParameters.Keys){
            Recurse{
                $Command += " -recurse"
            }
            Force{
                $Command += " -force"
            }
            Filter{
                $Command += " -Filter $Filter"
            }
            Incldue{
                $Command += " -Include"
                foreach($IncludeType in $Include){
                    $Command += " $IncludeType,"
                }
                $Command = $Command.TrimEnd(',')
            }
            Exclude{
                $Command += " -Exclude"
                foreach($ExcludeType in $Exclude){
                    $Command += " $ExcludeType,"
                }
                $Command = $Command.TrimEnd(',')
            }
        }
        #$Command += " | where-object {$" + "_.basename -ne 'System Volume Information'}"
        #$Command
        Try{
            Invoke-Expression $Command
        }catch{
            Write-Warning "Could not retrieve items. Either the parameters were incorrect or force parameter was used
            for hidden files."
            Write-Error $Error[0]
        }
    }
    
    end {
    }
}