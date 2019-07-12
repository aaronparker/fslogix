function New-FslDirectory {
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    param (
        [Parameter (Position = 0,
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'Name')]
        [Alias("Name")]
        [System.String]$SamAccountName,

        [Parameter (Position = 1,
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'Name')]
        [System.String]$SID,

        [Parameter (Position = 0,
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'AdUser')]
        [Alias("User")]
        [System.String]$AdUser,

        [Parameter (Mandatory = $True,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [System.String]$Destination,

        [Switch]$FlipFlop,

        [Switch]$Passthru
    )
    
    begin {
        Set-StrictMode -Version Latest
        #Requires -RunAsAdministrator
        #Requires -Modules "ActiveDirectory"
    }
    
    process {
        
        if ($PSBoundParameters.ContainsKey("Aduser")) {
            Try {
                $User = Get-AdUser $AdUser -ErrorAction Stop
                $SamAccountName = $User.Samaccountname
                $SID = $User.SID
            }
            Catch {
                Write-Error $Error[0]
            }
        }
        
        if ($PSBoundParameters.ContainsKey("FlipFlop")) {
            $User_Dir_Name = $SID + "_" + $SamAccountName
        }
        else {
            $User_Dir_Name = $SamAccountName + "_" + $SID
        }

        if ($Destination.ToLower().Contains("%username%")) {
            $Directory = $Destination -replace "%Username%", $User_Dir_Name
        }
        else {
            $Directory = Join-Path ($Destination) ($User_Dir_Name)
        }

        If (Test-Path -Path $Directory) {
            Write-Verbose "Directory exists: $Directory"
            # Remove-item -Path $Directory -Force -Recurse -ErrorAction SilentlyContinue
        }
        Else {
            Try {
                New-Item -Path $Directory -ItemType Directory -Force -ErrorAction Stop | Out-Null
                Write-Verbose "Created directory: $Directory"
            }
            catch {
                Write-Error $Error[0]
            }
        }

        if ($PSBoundParameters.ContainsKey("Passthru")) {
            $Directory
        }
    }
    
    end {
    }
}