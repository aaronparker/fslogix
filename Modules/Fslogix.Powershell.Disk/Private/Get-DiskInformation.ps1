Function Get-DiskInformation{
    [CmdletBinding()]
    param(
        [Parameter (Position = 0,
                    Mandatory = $true,
                    ValueFromPipeline = $true,
                    ValueFromPipelineByPropertyName = $true)]
        [System.String]$Path
    ) 

    Try{
        $VHD        = Get-Diskimage -ImagePath $Path -ErrorAction Stop
        $VHD_Item   = Get-Item -path $Path -ErrorAction Stop
    }catch{
        Write-Error $Error[0]
    }

    $Format     = $VHD_Item.Extension.TrimStart('.')
    $Extension  = $VHD_Item.Extension
    $Name       = split-path -path $Path -Leaf
    $BaseName   = $VHD_Item.BaseName
    $SizeGb     = $VHD.Size / 1gb
    $SizeMb     = $VHD.Size / 1mb
    $FreeSpace  = [Math]::Round((($VHD.Size - $VHD.FileSize) / 1gb) , 2)
    
    $VHD | Add-Member @{ ComputerName   = $Env:COMPUTERNAME}
    $VHD | Add-Member @{ Name           = $Name}
    $VHD | Add-Member @{ BaseName       = $BaseName}
    $VHD | Add-Member @{ Format         = $Format}
    $VHD | Add-Member @{ Extension      = $Extension}
    $VHD | Add-Member @{ SizeGb         = $SizeGb}
    $VHD | Add-Member @{ SizeMb         = $SizeMb}
    $VHD | Add-Member @{ FreeSpaceGB      = $FreeSpace}

    Write-Output $VHD
}