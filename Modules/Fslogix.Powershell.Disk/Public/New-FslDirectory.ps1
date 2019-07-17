Function New-FslDirectory {
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    Param (
        [Parameter (Position = 0, Mandatory = $True, ParameterSetName = 'Name')]
        [Alias("Name")]
        [System.String] $SamAccountName,

        [Parameter (Position = 1, Mandatory = $True, ParameterSetName = 'Name')]
        [System.String] $SID,

        [Parameter (Position = 0, Mandatory = $True, ParameterSetName = 'AdUser')]
        [Alias("User")]
        [System.String] $AdUser,

        [Parameter (Mandatory = $True)]
        [System.String] $Destination,

        [System.Management.Automation.SwitchParameter] $FlipFlop,

        [System.Management.Automation.SwitchParameter] $Passthru
    )
    
    Begin {
        Set-StrictMode -Version Latest
        #Requires -RunAsAdministrator
        #Requires -Modules "ActiveDirectory"
    }
    Process {   
        If ($PSBoundParameters.ContainsKey("AdUser")) {
            Try {
                $User = Get-AdUser -Identity $AdUser -ErrorAction Stop
                $SamAccountName = $User.SamAccountName
                $SID = $User.SID
            }
            Catch {
                Write-Error $Error[0]
            }
        }
        
        If ($PSBoundParameters.ContainsKey("FlipFlop")) {
            $UserDirName = "$($SamAccountName)_$($SID)"
        }
        Else {
            $UserDirName = "$($SID)_$($SamAccountName)"
        }

        If ($Destination.ToLower().Contains("%username%")) {
            $Directory = $Destination -replace "%Username%", $UserDirName
        }
        Else {
            $Directory = Join-Path -Path $Destination -ChildPath $UserDirName
        }

        If (Test-Path -Path $Directory) {
            Write-Verbose "Directory exists: $Directory"
            # Remove-Item -Path $Directory -Force -Recurse -ErrorAction SilentlyContinue
        }
        Else {
            Try {
                New-Item -Path $Directory -ItemType Directory -Force -ErrorAction Stop | Out-Null
                Write-Verbose "Created directory: $Directory"
            }
            Catch {
                Write-Error $Error[0]
            }
        }

        If ($PSBoundParameters.ContainsKey("Passthru")) {
            Write-Output -InputObject $Directory
        }
    }
    End {
    }
}
