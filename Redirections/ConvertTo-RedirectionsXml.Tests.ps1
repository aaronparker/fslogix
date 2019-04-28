<#
    Pester tests for ConvertTo-RedirectionsXml.ps1
#>

#region Setup
If (Test-Path 'env:APPVEYOR_BUILD_FOLDER') {
    # AppVeyor Testing
    $projectRoot = $env:APPVEYOR_BUILD_FOLDER
    Write-Host -ForegroundColor Cyan "Project root is: $projectRoot"
}
Else {
    # Local Testing 
    $projectRoot = "$(Split-Path -Parent -Path $MyInvocation.MyCommand.Definition)"
    Write-Host -ForegroundColor Cyan "Project root is: $projectRoot"
}

# Get variables
$scripts = Get-ChildItem "$projectRoot" -Recurse -Include "ConvertTo-RedirectionsXml.ps1"
$RedirectionsUri = "https://raw.githubusercontent.com/aaronparker/FSLogix/master/Redirections/Redirections.csv"
#endregion

#region Tests
Describe "General project validation" {
    # TestCases are splatted to the script so we need hashtables
    $testCase = $scripts | ForEach-Object { @{file = $_ } }
    It "Script <file> should be valid PowerShell" -TestCases $testCase {
        param($file)
        $file.FullName | Should Exist

        $contents = Get-Content -Path $file.FullName -ErrorAction Stop
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize($contents, [ref]$errors)
        $errors.Count | Should Be 0
    }

    $scriptAnalyzerRules = Get-ScriptAnalyzerRule
    It "<file> should pass ScriptAnalyzer" -TestCases $testCase {
        param ($file)
        $analysis = Invoke-ScriptAnalyzer -Path  $file.FullName -ExcludeRule @('PSAvoidGlobalVars', 'PSAvoidUsingConvertToSecureStringWithPlainText', 'PSAvoidUsingWMICmdlet') -Severity @('Warning', 'Error')   
        
        ForEach ($rule in $scriptAnalyzerRules) {        
            if ($analysis.RuleName -contains $rule) {
                $analysis | `
                    Where-Object RuleName -eq $rule -OutVariable failures | `
                    Out-Default
                $failures.Count | Should Be 0
            }
        }
    }
}

Describe "ConvertTo-RedirectionsXml.ps1" {
    If (Test-Path -Path (Join-Path $PWD "redirections.xml")) { Remove-Item -Path (Join-Path $PWD "redirections.xml") -Force }
    ForEach ($script in $scripts) {
        Write-Host -ForegroundColor Cyan "Script: $($script.FullName)"
        $file = . $script.FullName -Verbose
    }

    It "Should output redirections.xml to disk" {
        Write-Host -ForegroundColor Cyan "File: $file"
        $file | Should Exist
    }

    It "Should output redirections.xml as XML" {
        $Content = Get-Content -Path $file -Raw
        $Xml = $Content | ConvertTo-Xml
        $Xml | Should -BeOfType System.Xml.XmlNode
    }
}

Describe "Test Redirections CSV source" {
    It "Should exist at the known URL" {
        $r = Invoke-WebRequest -Uri $RedirectionsUri -UseBasicParsing
        $r.StatusCode | Should -Be "200"
    }

    It "Should convert from CSV format" {
        $Csv = Get-RedirectionsCsv
        $Redirections = ($Csv.Content | ConvertFrom-Csv)
        $Redirections | Should -BeOfType PSCustomObject
    }
}
#endregion
