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

# Variables
$TargetPath = "$env:LocalAppData\Microsoft\Outlook"

# find key that has the 001f6610 property that holds the OST file path - one key per outlook profile.
$ostRegValue = '001f6610'
$keyPath = "HKCU:\Software\Microsoft\Office\16.0\Outlook\Profiles\"
$keys = @((Get-ChildItem $keyPath -Recurse | `
            Where-Object { $_.Property -eq $ostRegValue }).Name )

ForEach ($key in $keys) {
    Write-Verbose -Message "Key: $key"
    $key = $key.Replace("HKEY_CURRENT_USER", "HKCU:")

    # $value = (Get-ItemProperty -Path $key -name $ostRegValue).$ostRegValue
    $ostOldPathHex = (Get-ItemProperty -Path $key | Select-Object -ExpandProperty $ostRegValue) -join ','

    $ostOldPath = ConvertFrom-Hex $ostOldPathHex
    Write-Verbose -Message "Old OST path: $ostOldPath"

    # make sure it is an OST in this field
    If ($ostOldPath.SubString($ostOldPath.length - 4, 4) -eq ".ost") {

        $oldOstFileName = $ostOldPath.Split("\")
        $oldOstFileName = $oldOstFileName[$oldOstFileName.Count - 1]

        $newOstPath = Join-Path $TargetPath $oldOstFileName
        $newOstPathHex = ConvertTo-Hex $newOstPath
        $newOstPathHex = $newOstPathHex -join ','
        $newOstPathStr = ConvertFrom-Hex $newOstPathHex
        Write-Verbose -Message "New OST path: $newOstPathStr"

        # Set-ItemProperty -Path $key -name $ostRegValue -value $newOstPathHex
    }
}
