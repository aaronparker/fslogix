function Confirm-Frx {
    [CmdletBinding()]
    param (
        [Parameter (Position = 0)]
        [System.String]$Path,

        [Parameter (Position = 1)]
        [Switch]$Passthru
    )
    
    begin {
        set-strictmode -version latest
    }
    
    process {

        if(!$PSBoundParameters.ContainsKey("$Path")){
            $Path = "HKLM:\SOFTWARE\FSLogix\Apps"
        }

        try {
            $InstallPath = (Get-ItemProperty $Path -ErrorAction Stop).InstallPath
        }
        catch {
            Write-Error "FsLogix Applications not found. Please intall FsLogix applications."
            exit
        }
        push-Location
        Set-Location -path $InstallPath
        
        $frxPath = Join-Path ($InstallPath) ("frx.exe")
        if ( -not (Test-Path -path $frxPath )) {
            Pop-Location
            Write-Error 'frx.exe Not Found. Please reinstall FsLogix Applications.'
            exit
        }
        Pop-Location
        
        if($Passthru){
            $frxPath
        }
    }
    
    end {
    }
}