function Get-FslSize {
    [CmdletBinding(DefaultParameterSetName = "None")]
    param (
        [Parameter( Position = 0,
                    Mandatory = $true,
                    ValueFromPipeline = $true,
                    ValueFromPipelineByPropertyName = $true)]
        [String[]]$path,

        [Parameter(ParameterSetName = "MB")]
        [switch]$mb,

        [Parameter(ParameterSetName = "GB")]
        [switch]$gb
    )
    
    begin {
        Set-Strictmode -version latest
        $Size = 0
    }
    
    process {
    
        foreach($file in $Path){
            $Size += (Get-ChildItem -Path $file -Recurse | Measure-Object -Property Length -Sum -ErrorAction Stop).Sum
        }
       
        switch($PSCmdlet.ParameterSetName){
            'MB' {
                [Math]::round($Size/1mb,2)
            }
            'GB' {
                [Math]::round($Size/1gb,2)
            }
            Default {
                [Math]::round($Size,2)
            }
            
        }
    }
    
    end {
    }
}