<#
    Pester tests for ConvertTo-RedirectionsXml.ps1
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
[CmdletBinding()]
param()

BeforeDiscovery {
    $Scripts = Get-ChildItem "$Env:GITHUB_WORKSPACE\Redirections" -Recurse -Include "ConvertTo-RedirectionsXml.ps1"
}

Describe "Script validation: <Script.Name>" -ForEach $Scripts {
    BeforeAll {
        $Script = $_
    }

    Context "Validate PowerShell code" {
        It "Script should be valid PowerShell" {
            $contents = Get-Content -Path $Script.FullName -ErrorAction "Stop"
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($contents, [ref]$errors)
            $errors.Count | Should -Be 0
        }

        It "Should pass Test-ScriptFileInfo" {
            { Test-ScriptFileInfo -Path $Script.FullName } | Should -Not -Throw
        }
    }

    Context "Test Redirections.csv GitHub source" {
        BeforeAll {
            $RedirectionsUri = "https://raw.githubusercontent.com/aaronparker/fslogix/main/Redirections/Redirections.csv"
            $Csv = Invoke-WebRequest -Uri $RedirectionsUri -UseBasicParsing
        }

        It "Should exist at the known URL" {
            (Invoke-WebRequest -Uri $RedirectionsUri -UseBasicParsing).StatusCode | Should -Be "200"
        }

        It "Should convert from CSV format" {
            $Redirections = ($Csv.Content | ConvertFrom-Csv)
            $Redirections | Should -BeOfType PSCustomObject
        }
    
        It "Should have expected properties" {
            $Redirections = ($Csv.Content | ConvertFrom-Csv)
            $Redirections.Action.Length | Should -BeGreaterThan 0
            $Redirections.Copy.Length | Should -BeGreaterThan 0
            $Redirections.Path.Length | Should -BeGreaterThan 0
            $Redirections.Description.Length | Should -BeGreaterThan 0
        }
    }

    Context "Validate ConvertTo-RedirectionsXml.ps1 default functionality" {
        It "Should not throw when passed no parameters" {
            { $File = & $Script.FullName } | Should -Not -Throw
        }

        It "Should have written the Redirections.xml" {
            $File = Get-ChildItem -Path "$Env:GITHUB_WORKSPACE\Redirections" -Recurse -Include "Redirections.xml"
            $File | Should -Exist
        }

        It "Should output redirections.xml as XML" {
            $File = Get-ChildItem -Path "$Env:GITHUB_WORKSPACE\Redirections" -Recurse -Include "Redirections.xml"
            $Content = Get-Content -Path $File -Raw
            $Xml = $Content | ConvertTo-Xml
            $Xml | Should -BeOfType System.Xml.XmlNode
        }

        AfterAll {
            # Remove redirections.xml to ensure a clean state for next test run
            $File = Get-ChildItem -Path "$Env:GITHUB_WORKSPACE\Redirections" -Recurse -Include "Redirections.xml"
            Remove-Item -Path $File -Force
        }
    }

    Context "Validate ConvertTo-RedirectionsXml.ps1 with a local CSV input file" {
        BeforeAll {
            $RedirectionsUri = "https://raw.githubusercontent.com/aaronparker/fslogix/main/Redirections/Redirections.csv"
            $LocalCsv = $(Join-Path -Path $PWD -ChildPath "RedirectionsLocal.csv")
            Invoke-WebRequest -Uri $RedirectionsUri -OutFile $LocalCsv -UseBasicParsing
        }

        It "Should read Redirections.csv from local disk" {
            { & $Script.FullName -Redirections $LocalCsv } | Should -Not -Throw
        }
    }

    Context "Validate ConvertTo-RedirectionsXml.ps1 throw scenarios" {
        It "Throws with invalid Redirections path input" {
            { & $Script.FullName -Redirections "$Env:Temp\Redirections.csv" } | Should -Throw
        }
    }
}
