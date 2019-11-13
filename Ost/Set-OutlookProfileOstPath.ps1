[CmdletBinding(SupportsShouldProcess = $True)]
[OutputType([System.String])]
Param (
    [Parameter(Mandatory = $false)]
    [System.String] $Path = "$env:LocalAppData\Microsoft\Outlook"
)

#region Functions
Function ConvertFrom-Hex ($String) {
    $output = ($String.Split(",", [System.StringSplitOptions]::RemoveEmptyEntries) | `
            Where-Object { $_ -gt '0' } | ForEach-Object { [char][int]"$($_)" }) -join ''
    Write-Output -InputObject $output
}

Function ConvertTo-Hex ($String) {
    $output = [System.Text.Encoding]::Unicode.GetBytes($String + "`0")
    Write-Output -InputObject $output
}

Function Set-RegValue {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)] $Key,
        [Parameter(Mandatory = $True)] $Value,
        [Parameter(Mandatory = $True)] $Data,
        [Parameter(Mandatory = $False)]
        [ValidateSet('Binary', 'ExpandString', 'String', 'Dword', 'MultiString', 'QWord')]
        [System.String] $Type = "String"
    )
    try {
        If (!(Test-Path -Path $Key)) {
            New-Item -Path $Key -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-Error "Failed to create key $Key with error $_."
        Break
    }
    finally {
        New-ItemProperty -Path $Key -Name $Value -Value $Data -PropertyType $Type -Force
    }
}
#endregion

# Find key that has the 001f6610 property that holds the OST file path - one key per Outlook profile.
$ostRegValue = "001f6610"
$keyPath = "HKCU:\Software\Microsoft\Office\16.0\Outlook\Profiles"
$keys = (Get-ChildItem $keyPath -Recurse | `
        Where-Object { $_.Property -eq $ostRegValue }).Name

ForEach ($key in $keys) {
    $key = $key.Replace("HKEY_CURRENT_USER", "HKCU:")
    Write-Verbose -Message "Key: $key"

    # Grab the old path to the OST file
    $ostOldPathHex = (Get-ItemProperty -Path $key | Select-Object -ExpandProperty $ostRegValue) -join ','
    $ostOldPath = ConvertFrom-Hex $ostOldPathHex
    Write-Verbose -Message "Old OST path: $ostOldPath"
    $oldOstFile = Split-Path -Path $ostOldPath -Leaf
     
    # make sure it is an OST in this field
    If ([IO.Path]::GetExtension($oldOstFile) -match ".ost") {

        # Build a path to the new file and encode in Hex
        $oldOstFileName = Split-Path -Path $ostOldPath -Leaf
        $newOstPath = Join-Path -Path $Path -ChildPath $oldOstFileName
        $newOstPathHex = [System.Text.Encoding]::Unicode.GetBytes($newOstPath + "`0")
        $newOstPathStr = ConvertFrom-Hex -String ($newOstPathHex -join ',')
        Write-Verbose -Message "New OST path: $newOstPathStr"

        # Set registry value with new OST file path
        If ($pscmdlet.ShouldProcess($newOstPathStr, "Set Registry")) {
            Set-RegValue -Key $key -Value $ostRegValue -Data $newOstPathHex -Type 'Binary'
        }
    }
}
