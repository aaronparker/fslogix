function Get-FslExtension {
    [CmdletBinding()]
    param (
        [Parameter (Position = 0,
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [System.String]$Path
    )
    
    begin {
        Set-Strictmode -Version latest

        $Extension = $null
        $charArray = $Path.tochararray()
        $CurIndex = $charArray.length - 1
        $FullLength = $charArray.length
    }
    
    process {
        
        while ($CurIndex -ge 0) {

            if($charArray[$CurIndex] -eq '\'){
                break
            }

            if ($charArray[$CurIndex] -eq '.') {
                $Ending = $FullLength - $CurIndex
                $Extension = $Path.substring($CurIndex, $Ending)
                break
            }
            else {
                $CurIndex--
            }
        }
        $Extension

    }#Process
    
    end {
    }
}