Function Confirm-FslProfile {
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, Mandatory = $True)]
        [System.String] $Path,

        [Parameter(Position = 1, Mandatory = $True)]
        [System.String] $SamAccountName,

        [Parameter(Position = 2, Mandatory = $True)]
        [System.String] $SID,

        [Parameter(Mandatory = $False)]
        [System.Management.Automation.SwitchParameter] $FlipFlop,

        [Parameter(Mandatory = $False)]
        [System.Management.Automation.SwitchParameter] $VHD
    )
    
    Begin {
        Set-StrictMode -Version Latest
        #Requires -RunAsAdministrator
        #Requires -Modules "ActiveDirectory"
    }
    Process {
        If ($PSBoundParameters.ContainsKey("FlipFlop")) {
            $Directory = "$($SamAccountName)_$($SID)"
        }
        Else {
            $Directory = "$($SID)_$($SamAccountName)"
        }

        $Path = Join-Path -Path $Path -ChildPath $Directory
        If (-not(Test-Path -Path $Path)) {
            Write-Warning -Message "Could not find path: $Path"
            Break
        }

        If ($SamAccountName -like "*@*") {
            $VHDName = "ODFC_$(($SamAccountName -split "@")[0])"
        }
        Else {
            $VHDName = "ODFC_$($SamAccountName)"
        }
        If ($PSBoundParameters.ContainsKey("VHD")) {
            $VHDName += ".vhd"
        }
        Else {
            $VHDName += ".vhdx"
        }
                
        $VHDPath = Join-Path -Path $Path -ChildPath $VHDName
        If (Test-Path -path $VHDPath) {
            $IsFslProfile = $True
        }
        Else {
            Write-Warning "Could not find VHD: $VHDPath"
            $IsFslProfile = $False
        }
        Write-Output -InputObject $IsFslProfile
    }
    End {
    }
}