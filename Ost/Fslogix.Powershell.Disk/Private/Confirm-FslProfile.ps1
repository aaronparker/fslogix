function Confirm-FslProfile {
    [CmdletBinding(DefaultParameterSetName = 'User')]
    param (

        [Parameter(Position = 0,
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'User')]
        [System.String]$Path,

        [Parameter(Position = 1,
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'User')]
        [System.String]$SamAccountName,

        [Parameter(Position = 2,
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'User')]
        [System.String]$SID,

        [Switch]$FlipFlop,

        [Switch]$VHD
        
    )
    
    begin {
        Set-Strictmode -Version Latest
        #Requires -RunAsAdministrator
        #Requires -Modules "ActiveDirectory"
        $IsFslProfile = $False
    }
    
    process {
        switch($PSCmdlet.ParameterSetName){
            User{
                
                if($PSBoundParameters.ContainsKey("FlipFlop")){
                    $Directory = $SID + "_" + $SamAccountName
                }else{
                    $Directory = $SamAccountName + "_" + $SID
                }

                $Path = join-path ($Path) ($Directory)
                if(-not(test-path -path $Path)){
                    Write-Warning "Could not find path: $Path"
                    break
                }

                $VHDName = "ODFC_" + $SamAccountName
                if($PSBoundParameters.ContainsKey("VHD")){
                    $VHDName += ".vhd"
                }else{
                    $VHDName += ".vhdx"
                }
                
                $VHDPath = join-path ($Path) ($VHDName)
                if(-not(test-path -path $VHDPath)){
                    Write-Warning "Could not find VHD: $VHDPath"
                }else{
                    $IsFslProfile = $true
                }
            }
        }

        $IsFslProfile
    }
    
    end {
    }
}