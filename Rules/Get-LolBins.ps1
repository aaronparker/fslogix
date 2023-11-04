$dotnetProgramsToDenyList =
"AddInProcess.exe",
"AddInProcess32.exe",
"AddInUtil.exe",
"aspnet_compiler.exe",
"IEExec.exe",
"InstallUtil.exe",
"Microsoft.Build.dll",
"Microsoft.Build.Framework.dll",
"Microsoft.Workflow.Compiler.exe",
"MSBuild.exe",
"RegAsm.exe",
"RegSvcs.exe",
"System.Management.Automation.dll"
$dotnetProgramsToDenyList | ForEach-Object {
    Get-ChildItem -Path "$Env:SystemRoot\Microsoft.NET" -Recurse -Include $_ | ForEach-Object { $_.FullName }
}

# Additional Microsoft recommended executables to deny
"Microsoft.Build.Framework.dll", "System.Management.Automation.dll" | ForEach-Object {
    Get-ChildItem -Path "$Env:SystemRoot\assembly\GAC_MSIL" -Recurse -Include $_ | ForEach-Object { $_.FullName }
}

# Additional Microsoft recommended executables to deny
"bash.exe", "wsl.exe", "wslconfig.exe", "wslhost.exe", "system.management.automation.dll", "lxssmanager.dll", "cscript.exe", "wscript.exe" | `
    ForEach-Object {
    Get-ChildItem -Path "$Env:SystemRoot\servicing\LCU" -Recurse -Include $_ -ErrorAction "Ignore" | ForEach-Object { $_.FullName }
}

@("$Env:SystemRoot\System32\mshta.exe",
    "$Env:SystemRoot\System32\PresentationHost.exe",
    "$Env:SystemRoot\System32\wbem\WMIC.exe") | ForEach-Object { Get-ChildItem -Path $_ | ForEach-Object { $_.FullName } }
# Note: also need Code Integrity rules to block other bypasses

# --------------------------------------------------------------------------------
# Files used by ransomware / lolbins
@("$Env:SystemRoot\System32\cipher.exe",
    "$Env:SystemRoot\System32\certreq.exe",
    "$Env:SystemRoot\System32\certutil.exe",
    "$Env:SystemRoot\System32\Cmdl32.exe",
    "$Env:SystemRoot\System32\msdt.exe") | ForEach-Object { Get-ChildItem -Path $_ | ForEach-Object { $_.FullName } }

# --------------------------------------------------------------------------------
# Block common credential exposure risk (also need to disable GUI option via registry, and SecondaryLogon service)
@("$Env:SystemRoot\System32\runas.exe") | ForEach-Object { Get-ChildItem -Path $_ | ForEach-Object { $_.FullName } }

# Block Scripting host
@("$Env:SystemRoot\System32\cscript.exe",
    "$Env:SystemRoot\System32\wscript.exe") | ForEach-Object { Get-ChildItem -Path $_ | ForEach-Object { $_.FullName } }
