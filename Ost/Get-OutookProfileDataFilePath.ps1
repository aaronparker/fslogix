<#
    .SYNOPSIS
        Export the path to Outlook data files (PST / OST files) loaded in the user's Outlook profile
#>

[CmdletBinding(SupportsShouldProcess = $True)]
[OutputType([System.String])]
Param (
    [Parameter(Mandatory = $false)]
    [System.String] $LogPath
)

#region Functions
Function ConvertFrom-Hex ($String) {
    $output = ($String.Split(",", [System.StringSplitOptions]::RemoveEmptyEntries) | `
            Where-Object { $_ -gt '0' } | ForEach-Object { [char][int]"$($_)" }) -join ''
    Write-Output -InputObject $output
}
#endregion

# Output
$fileList = New-Object -TypeName System.Collections.ArrayList

# Find key that has the 001f6700 property that holds the PST file path
$pstRegValue = "001f6700"
$keyPath = "HKCU:\Software\Microsoft\Office\16.0\Outlook\Profiles"
$keys = (Get-ChildItem $keyPath -Recurse | `
        Where-Object { $_.Property -eq $pstRegValue }).Name

ForEach ($key in $keys) {
    $key = $key.Replace("HKEY_CURRENT_USER", "HKCU:")
    Write-Verbose -Message "Key: $key"

    # Grab the old path to the PST file
    $pstPathHex = (Get-ItemProperty -Path $key | Select-Object -ExpandProperty $pstRegValue) -join ','
    $pstPath = ConvertFrom-Hex $pstPathHex
    Write-Verbose -Message "PST file path: $pstPath"

    $PSObject = [PSCustomObject] @{
        samAccountName = $env:USERNAME
        Domain         = $env:USERDOMAIN
        Type           = "PST"
        Path           = $pstPath
    }
    $fileList.Add($PSObject) | Out-Null
}

# Find key that has the 001f6610 property that holds the OST file path
$ostRegValue = "001f6610"
$keyPath = "HKCU:\Software\Microsoft\Office\16.0\Outlook\Profiles"
$keys = (Get-ChildItem $keyPath -Recurse | `
        Where-Object { $_.Property -eq $ostRegValue }).Name

ForEach ($key in $keys) {
    $key = $key.Replace("HKEY_CURRENT_USER", "HKCU:")
    Write-Verbose -Message "Key: $key"

    # Grab the old path to the OST file
    $ostPathHex = (Get-ItemProperty -Path $key | Select-Object -ExpandProperty $ostRegValue) -join ','
    $ostPath = ConvertFrom-Hex $ostPathHex
    Write-Verbose -Message "OST file path: $ostPath"

    $PSObject = [PSCustomObject] @{
        samAccountName = $env:USERNAME
        Domain         = $env:USERDOMAIN
        Type           = "OST"
        Path           = $ostPath
    }
    $fileList.Add($PSObject) | Out-Null
}

If ($PSBoundParameters.ContainsKey('LogPath')) {
    Write-Verbose -Message "Output: $LogPath\$env:USERNAME.$env:USERDOMAIN.csv"
    $fileList | Export-Csv -Path $("$LogPath\$env:USERNAME.$env:USERDOMAIN.csv") -Delimiter "," -NoTypeInformation
}
Else {
    Write-Output -InputObject $fileList
}
