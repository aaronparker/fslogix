[CmdletBinding()]
[OutputType([String])]
Param (
    [Parameter(Mandatory = $false)]
    [string] $Path
)

#region Functions
Function ConvertFrom-Hex ($String) {
    ($String.Split(",", [System.StringSplitOptions]::RemoveEmptyEntries) | `
            Where-Object { $_ -gt '0' } | ForEach-Object { [char][int]"$($_)" }) -join ''
}

Function ConvertTo-Hex ($String) {
    [System.Text.Encoding]::Unicode.GetBytes($String + "`0")
}
#endregion

# Get keys
$pstRegValue = '001f6700'
$keyPath = "HKCU:\Software\Microsoft\Office\16.0\Outlook\Profiles\"
$keys = @((Get-ChildItem $keyPath -Recurse | `
            Where-Object { $_.Property -eq $pstRegValue }).Name)

ForEach ($key in $keys) {
    $key = $key.Replace("HKEY_CURRENT_USER", "HKCU:")
    $values = Get-Item -Path $key | Select-Object -ExpandProperty Property
    ForEach ($value in $values) {
        $item = Get-ItemProperty -Path $key -Name $value | Select-Object -ExpandProperty $value
        $string = ConvertFrom-Hex ($item -join ',')
        If ($string -like "*.pst") {
            Write-Output "Key: $key"
            Write-Output "$value : [$string]"
        }
    }
}
