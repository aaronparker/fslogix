<# INSERT HEADER ABOVE #>

#Get public and private function definition files.

#Requires -Version 5.0

function Add-FslAssignment {

    <#
        .SYNOPSIS
            Adds to the content of a FSLogix Rule assignment file.

        .DESCRIPTION
            This function can add to FSLogix assignment file contents, the assignment file should have the same basename as the matching rule file.
            This will not overwrite the contents of an existing file.

        .PARAMETER Path
            The Target file path to set the assignment within
        .PARAMETER RuleSetApplies
            This determines whether a ruleset does or does not apply to users/groups/processes etc.  For instance when using a Hiding rule, applying that hiding rule to users will hide the file from the users assigned to it when applied.
        .PARAMETER UserName
            If you wish to tie down the rule to an individual user use theier unsername in this parameter.  Groupname is more usual for assignments however
        .PARAMETER GroupName
            Use this to tie the assignment of the rule to a specific group
        .PARAMETER WellKnownSID
            The Well Known SID for groups such as Domain Admins are useful for cross-language assignments, if you use a group with a well known SID in the groupname parameter this will be automatically filled out, so mostly useful for pipeline input.
        .PARAMETER ADDistinguisedName
            Full Distinguished name of AD component
        .PARAMETER ProcessName
            Process name for the rule assignment, mostly used for redirect rules
        .PARAMETER IncludeChildProcess
            If Process name is stated you can optionally include chile prcesses (recommended)
        .PARAMETER IPAddress
            Enter the IPv4 or IPv6 address. Partial strings are allowed. For example, if you enter 192.168, an address of 192.168.0.1 will be considered to match.
        .PARAMETER ComputerName
            Enter the Full Distinguished Name of the computer object, or the computer name (wildcards accepted). Must be in the format ComputerName@Domain
        .PARAMETER OU
            You can specify an Active Directory Container and the assignment will be effective for all of the objects in that container. Enter the Full Distinguished Name of the container.
        .PARAMETER EnvironmentVariable
            By Specifying an environment variable, you can customize rules in various other ways. A very useful example for this option is when using it with RDSH, XenApp, or other remote sessions. You can use the Environment Variable CLIENTNAME to limit visibility to the device being used to access the RDSH or XenApp system.
            The environment variables that are supported are the ones that are present when the user's session is created. Environment variables set during logon are not supported.
        .PARAMETER AssignedTime
            Only used for pipeline input
        .PARAMETER UnAssignedTime
            Only used for pipeline input
        .EXAMPLE
            A sample command that uses the function or script, optionaly followed
            by sample output and a description. Repeat this keyword for each example.
    #>

    [CmdletBinding()]
    Param (

        [Parameter(
            Position = 1,
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [Alias('AssignmentFilePath')]
        [System.String]$Path,

        [Parameter(
            ParameterSetName = 'User',
            ValuefromPipelineByPropertyName = $true
        )]
        [Parameter(
            ParameterSetName = 'Group',
            ValuefromPipelineByPropertyName = $true
        )]
        [Parameter(
            ParameterSetName = 'Executable',
            ValuefromPipelineByPropertyName = $true
        )]
        [Parameter(
            ParameterSetName = 'Network',
            ValuefromPipelineByPropertyName = $true
        )]
        [Parameter(
            ParameterSetName = 'Computer',
            ValuefromPipelineByPropertyName = $true
        )]
        [Parameter(
            ParameterSetName = 'OU',
            ValuefromPipelineByPropertyName = $true
        )]
        [Parameter(
            ParameterSetName = 'EnvironmentVariable',
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$RuleSetApplies,

        [Parameter(
            ParameterSetName = 'User',
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$UserName,

        [Parameter(
            ParameterSetName = 'Group',
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$GroupName,

        [Parameter(
            ParameterSetName = 'Group',
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$WellKnownSID,

        [Parameter(
            ParameterSetName = 'User',
            ValuefromPipelineByPropertyName = $true
        )]
        [Parameter(
            ParameterSetName = 'Group',
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$ADDistinguisedName,

        [Parameter(
            ParameterSetName = 'Executable',
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$ProcessName,

        [Parameter(
            ParameterSetName = 'Executable',
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$IncludeChildProcess,

        [Parameter(
            ParameterSetName = 'Network',
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$IPAddress,

        [Parameter(
            ParameterSetName = 'Computer',
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [ValidatePattern(".*@.*")]
        [System.String]$ComputerName,

        [Parameter(
            ParameterSetName = 'OU',
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$OU,

        [Parameter(
            ParameterSetName = 'EnvironmentVariable',
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [ValidatePattern(".*=.*")]
        [System.String]$EnvironmentVariable,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$PassThru,

        [Parameter(
            ParameterSetName = 'AssignmentObjectPipeline',
            ValuefromPipeline = $true,
            ValuefromPipelineByPropertyName = $true
        )]
        [PSTypeName('FSLogix.Assignment')]$InputObject
    )

    BEGIN {
        Set-StrictMode -Version Latest
        #check file has correct filename extension
        if ($Path -notlike "*.fxa") {
            Write-Warning 'Assignment files should have an fxa extension'
        }
        if ( -not ( Test-Path $Path )) {
            $version = 1
            $minimumLicenseAssignedTime = 0
            Set-Content -Path $Path -Value "$version`t$minimumLicenseAssignedTime" -Encoding Unicode -ErrorAction Stop -WhatIf:$false
        }

    } # Begin
    PROCESS {

        $convertToFslAssignmentCodeParams = @{}

        $assignmentCode = $null
        $idString = $null
        $DistinguishedName = $null
        $FriendlyName = $null

        if ($PSCmdlet.ParameterSetName -eq 'AssignmentObjectPipeline') {
            $allFields = $InputObject
        }
        else {
            $allFields = [PSCustomObject]@{

                RuleSetApplies      = $RuleSetApplies
                UserName            = $UserName
                GroupName           = $GroupName
                ADDistinguisedName  = $ADDistinguisedName
                WellKnownSID        = $WellKnownSID
                ProcessName         = $ProcessName
                IncludeChildProcess = $IncludeChildProcess
                IPAddress           = $IPAddress
                ComputerName        = $ComputerName
                OU                  = $OU
                EnvironmentVariable = $EnvironmentVariable
                AssignedTime        = 0
                UnAssignedTime      = 0

            }
        }

        if ($allFields.RuleSetApplies) {
            $convertToFslAssignmentCodeParams += @{ 'Apply' = $true }
        }
        else {
            $convertToFslAssignmentCodeParams += @{ 'Remove' = $true }
        }


        if ($allFields.UserName) {

            $convertToFslAssignmentCodeParams += @{ 'User' = $true }

            if ($allFields.ADDistinguisedName) {
                $convertToFslAssignmentCodeParams += @{ 'ADDistinguishedName' = $true }
                $distinguishedName = $allFields.ADDistinguisedName
            }

            $idString = $allFields.UserName
            $friendlyName = $allFields.UserName
        }

        if ( $allFields.GroupName ) {

            $convertToFslAssignmentCodeParams += @{ 'Group' = $true }

            if ( $allFields.ADDistinguisedName ) {
                $convertToFslAssignmentCodeParams += @{ 'ADDistinguishedName' = $true }
                $distinguishedName = $allFields.ADDistinguisedName
            }

            #Determine if the group has a Well Known SID
            $wellknownSids = [Enum]::GetValues([System.Security.Principal.WellKnownSidType])
            $account = New-Object System.Security.Principal.NTAccount($allFields.GroupName)
            $sid = $account.Translate([System.Security.Principal.SecurityIdentifier])
            $result = foreach ($s in $wellknownSids) { $sid.IsWellKnown($s)}

            if ( $result -contains $true ) {
                $idString = $sid.Value
            }
            else {
                $idString = $allFields.GroupName
            }

            $friendlyName = $allFields.GroupName
        }

        if ( $allFields.ProcessName ) {

            $convertToFslAssignmentCodeParams += @{ 'Process' = $true }

            if ($allFields.IncludeChildProcess) {
                $convertToFslAssignmentCodeParams += @{ 'ApplyToProcessChildren' = $true }
            }

            $idString = $allFields.ProcessName

        }

        if ( $allFields.IPAddress ) {
            $convertToFslAssignmentCodeParams += @{ 'Network' = $true }
            $idString = $allFields.IPAddress
        }

        if ( $allFields.ComputerName ) {
            $convertToFslAssignmentCodeParams += @{ 'Computer' = $true }
            $idString = $allFields.ComputerName
        }

        if ( $allFields.OU ) {
            $convertToFslAssignmentCodeParams += @{ 'ADDistinguishedName' = $true }
            $idString = $allFields.OU
        }

        if ( $allFields.EnvironmentVariable ) {
            $convertToFslAssignmentCodeParams += @{ 'EnvironmentVariable' = $true }
            $idString = $allFields.EnvironmentVariable
            if ( $allFields.AssignedTime -eq 0 -and $convertToFslAssignmentCodeParams.Remove -eq $true ) {
                $allFields.AssignedTime = (Get-Date).ToFileTime()
            }
        }


        if ( $allFields.AssignedTime -is [DateTime] ) {
            $AssignedTime = $allFields.AssignedTime.ToFileTime()
        }
        else {
            $AssignedTime = $allFields.AssignedTime
        }

        if ( $allFields.UnAssignedTime -is [DateTime] ) {
            $UnAssignedTime = $allFields.UnAssignedTime.ToFileTime()
        }
        else {
            $UnAssignedTime = $allFields.UnAssignedTime
        }

        if ( -not (Test-Path variable:script:DistinguishedName) ) {
            $DistinguishedName = ''
        }

        $assignmentCode = ConvertTo-FslAssignmentCode @convertToFslAssignmentCodeParams

        $message = "$assignmentCode`t$idString`t$DistinguishedName`t$FriendlyName`t$AssignedTime`t$UnAssignedTime"

        $addContentParams = @{
            'Path'     = $Path
            'Encoding' = 'Unicode'
            'Value'    = $message
            'WhatIf'   = $false
        }

        Add-Content @addContentParams

        Write-Verbose -Message "Written $message to $Path"

        if ($passThru) {
            $passThruObject = [pscustomobject]@{
                AssignmentCode    = $assignmentCode
                IdString          = $idString
                DistinguishedName = $DistinguishedName
                FriendlyName      = $FriendlyName
                AssignedTime      = $AssignedTime
                UnAssignedTime    = $UnAssignedTime
            }
            Write-Output $passThruObject
        }
    } #Process
    END {} #End
}  #function Add-FslAssignment
function Add-FslRule {
    [CmdletBinding()]

    Param (

        [Parameter(
            Position = 1,
            Mandatory = $true,
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$RuleFilePath,

        [Parameter(
            ParameterSetName = 'Hiding',
            Position = 2,
            ValueFromPipeline = $true,
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [Parameter(
            ParameterSetName = 'Redirect',
            Position = 2,
            ValueFromPipeline = $true,
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [Parameter(
            ParameterSetName = 'AppContainer',
            Position = 2,
            ValueFromPipeline = $true,
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [Parameter(
            ParameterSetName = 'SpecifyValue',
            Position = 2,
            ValueFromPipeline = $true,
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [Alias('Name')]
        [System.String]$FullName,

        [Parameter(
            ParameterSetName = 'Hiding',
            Mandatory = $true,
            Position = 3,
            ValuefromPipelineByPropertyName = $true
        )]
        [ValidateSet('FolderOrKey', 'FileOrValue', 'Font', 'Printer')]
        [System.String]$HidingType,

        [Parameter(
            ParameterSetName = 'Redirect',
            Mandatory = $true,
            Position = 6,
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$RedirectDestPath,

        [Parameter(
            ParameterSetName = 'Redirect',
            Mandatory = $true,
            Position = 7,
            ValuefromPipelineByPropertyName = $true
        )]
        [ValidateSet('FolderOrKey', 'FileOrValue')]
        [System.String]$RedirectType,

        [Parameter(
            ParameterSetName = 'Redirect',
            Position = 8,
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$CopyObject,

        [Parameter(
            ParameterSetName = 'AppContainer',
            Mandatory = $true,
            Position = 9,
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$DiskFile,

        [Parameter(
            ParameterSetName = 'SpecifyValue',
            Mandatory = $true,
            Position = 10,
            ValuefromPipelineByPropertyName = $true
        )]
        [Alias('Binary')]
        [System.String]$Data,

        [Parameter(
            Position = 11,
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$Comment = 'Created By PowerShell Script',

        [Parameter(
            Position = 13,
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$Passthru,

        [Parameter(
            ParameterSetName = 'RuleObjectPipeline',
            ValuefromPipeline = $true,
            ValuefromPipelineByPropertyName = $true
        )]
        [PSTypeName('FSLogix.Rule')]$RuleObject
    )

    BEGIN {
        Set-StrictMode -Version Latest

        $FRX_RULE_SRC_IS_A_FILE_OR_VALUE = 0x00000002
        $FRX_RULE_TYPE_REDIRECT = 0x00000100

    } # Begin
    PROCESS {

        if ( -not ( Test-Path $RuleFilePath )) {
            $version = 1
            Set-Content -Path $RuleFilePath -Value $version -Encoding Unicode -ErrorAction Stop
        }
        #check file has correct filename extension
        if ($RuleFilePath -notlike "*.fxr") {
            Write-Warning 'Rule files should have an fxr extension'
        }

        $convertToFslRuleCodeParams = @{}

        switch ($PSCmdlet.ParameterSetName) {

            Hiding {
                switch ($true) {
                    { $HidingType -eq 'Font' } { $convertToFslRuleCodeParams += @{ 'HideFont' = $true }
                    }
                    { $HidingType -eq 'Printer' } { $convertToFslRuleCodeParams += @{ 'Printer' = $true }
                    }
                    { $HidingType -eq 'FileOrValue'} { $convertToFslRuleCodeParams += @{ 'FileOrValue' = $true }
                    }
                    { $HidingType -eq 'FolderOrKey'} { $convertToFslRuleCodeParams += @{ 'FolderOrKey' = $true }
                    }
                    { $HidingType -ne 'Font' -and $HidingType -ne 'Printer' } { $convertToFslRuleCodeParams += @{ 'Hiding' = $true }
                    }
                }
                break
            }
            Redirect {
                $convertToFslRuleCodeParams += @{ 'Redirect' = $true }

                switch ($true) {
                    { $RedirectType -eq 'FileOrValue'} { $convertToFslRuleCodeParams += @{ 'FileOrValue' = $true }
                    }
                    { $RedirectType -eq 'FolderOrKey'} { $convertToFslRuleCodeParams += @{ 'FolderOrKey' = $true }
                    }
                }
                $convertToFslRuleCodeParams += @{
                    'CopyObject' = $CopyObject
                }

                break
            }
            AppContainer {
                $convertToFslRuleCodeParams += @{ 'VolumeAutomount' = $true }
                break
            }
            SpecifyValue {
                $convertToFslRuleCodeParams += @{ 'SpecificData' = $true }
                break
            }
            RuleObjectPipeline {
                if ($RuleObject.HidingType) {
                    switch ($true) {
                        { $RuleObject.HidingType -eq 'Font' } { $convertToFslRuleCodeParams += @{ 'HideFont' = $true }
                        }
                        { $RuleObject.HidingType -eq 'Printer' } { $convertToFslRuleCodeParams += @{ 'Printer' = $true }
                        }
                        { $RuleObject.HidingType -eq 'FileOrValue'} { $convertToFslRuleCodeParams += @{ 'FileOrValue' = $true }
                        }
                        { $RuleObject.HidingType -eq 'FolderOrKey'} { $convertToFslRuleCodeParams += @{ 'FolderOrKey' = $true }
                        }
                        { $RuleObject.HidingType -ne 'Font' -and $RuleObject.HidingType -ne 'Printer' } { $convertToFslRuleCodeParams += @{ 'Hiding' = $true }
                        }
                    }
                }
                if ($RuleObject.RedirectType) {
                    $convertToFslRuleCodeParams += @{ 'Redirect' = $true }
                    switch ($true) {
                        { $RuleObject.RedirectType -eq 'FileOrValue'} { $convertToFslRuleCodeParams += @{ 'FileOrValue' = $true }
                        }
                        { $RuleObject.RedirectType -eq 'FolderOrKey'} { $convertToFslRuleCodeParams += @{ 'FolderOrKey' = $true }
                        }
                    }
                }
                if ($RuleObject.DiskFile) {
                    $convertToFslRuleCodeParams += @{ 'VolumeAutomount' = $true }
                }
                if ($RuleObject.Data) {
                    $convertToFslRuleCodeParams += @{ 'SpecificData' = $true }
                }
                if ($RuleObject.CopyObject) {
                    $convertToFslRuleCodeParams += @{ 'CopyObject' = $true }
                }
                $FullName = $RuleObject.FullName
                $RedirectDestPath = $RuleObject.RedirectDestPath
            }

        }

        $flags = ConvertTo-FslRuleCode @convertToFslRuleCodeParams


        if ($flags -band  $FRX_RULE_SRC_IS_A_FILE_OR_VALUE) {
            $sourceParent = Split-Path $FullName -Parent
            $source = Split-Path $FullName -Leaf
        }
        else {
            $sourceParent = $FullName
            $source = $null
        }

        if ($flags -band $FRX_RULE_SRC_IS_A_FILE_OR_VALUE -and
            $flags -band $FRX_RULE_TYPE_REDIRECT) {
            $destParent = Split-Path $RedirectDestPath -Parent
            $dest = Split-Path $RedirectDestPath -Leaf
        }
        else {
            $destParent = $RedirectDestPath
            $dest = $null
        }

        #Binary is an unused field in fxr files
        $binary = $null

        $addContentParams = @{
            'Path'     = $RuleFilePath
            'Encoding' = 'Unicode'
            'WhatIf'   = $false
        }

        Add-Content @addContentParams -Value "##$Comment"
        Write-Verbose -Message "Written $Comment to $RuleFilePath"

        If ($convertToFslRuleCodeParams.ContainsKey( 'CopyObject' ) -and
            $convertToFslRuleCodeParams.ContainsKey( 'Redirect' ) -and
            $convertToFslRuleCodeParams.ContainsKey( 'FolderOrKey' ) ) {
            $SourceParent = $SourceParent.TrimEnd('\') + '\'
            $destParent = $destParent.TrimEnd('\') + '\'
        }
        else {
            $destParent = $destParent.TrimEnd('\')
        }

        $message = "$SourceParent`t$Source`t$DestParent`t$Dest`t$Flags`t$binary"

        Add-Content @addContentParams -Value $message

        Write-Verbose -Message "Written $message to $RuleFilePath"

        If ($passThru) {
            $passThruObject = [pscustomobject]@{
                SourceParent = $SourceParent
                Source       = $Source
                DestParent   = $DestParent
                Dest         = $Dest
                Flags        = $Flags
                binary       = $binary
                Comment      = $Comment
            }
            Write-Output $passThruObject
        }
    } #Process
    END {} #End
}  #function Add-FslRule

function Compare-FslFilePath {
    [CmdletBinding()]

    Param (
        [Parameter(
            Position = 0,
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [System.Array[]]$Files,

        [Parameter(
            Position = 0,
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$OutputPath = "$PSScriptRoot"
    )

    BEGIN {
        Set-StrictMode -Version Latest
    } # Begin
    PROCESS {

        foreach ($filepath in $Files) {
            if (-not (Test-Path $filepath)) {
                Write-Error "$filepath does not exist"
                exit
            }
        }

        $allFiles = @()
        foreach ($filepath in $Files) {
            $appFiles = ( Import-Clixml $filepath ).FullName
            $allfiles += $appFiles
        }

        $dupes = $allFiles | Group-Object | Where-Object { $_.Count -gt 1 } | Select-Object -ExpandProperty Name

        $uniqueFiles = @{}

        foreach ($filepath in $Files) {

            $baseFileName = $filepath | Get-ChildItem | Select-Object -ExpandProperty BaseName

            $newFileName = "$($baseFileName)_UniqueHiding.fxr"

            $currentAppFiles = ( Import-Clixml $filepath ).FullName

            $uniqueFiles = $currentAppFiles | Where-Object { $dupes -notcontains $_ }

            $uniqueFiles | Set-FslRule -HidingType FileOrValue -RuleFilePath ( Join-Path $OutputPath $newFileName )

        }

    } #Process
    END {} #End
}  #function Compare-FslFilePath

function Compare-FslRuleFile {
    [CmdletBinding()]

    Param (
        [Parameter(
            Position = 0,
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [System.Array]$Files,

        [Parameter(
            Position = 0,
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$OutputPath = "$PSScriptRoot"
    )

    BEGIN {
        Set-StrictMode -Version Latest
    } # Begin
    PROCESS {

        foreach ($filepath in $Files) {
            if (-not (Test-Path $filepath)) {
                Throw "$filepath does not exist"
            }
        }

        foreach ($filepath in $Files) {
            $diffRule = @()

            $referenceFile = $filepath
            $baseFileName = $filepath | Get-ChildItem | Select-Object -ExpandProperty BaseName
            $rules = Get-FslRule -Path $filepath
            #Get hiding rules (only concerned with hiding rules that are registry keys)
            $refRule = $rules | Where-Object { $_.HidingType -eq 'FolderOrKey' -and $_.FullName -like "HKLM*"} | Select-Object -ExpandProperty FullName

            foreach ($filepath in $Files) {
                if ($filepath -ne $referenceFile) {
                    $notRefRule = Get-FslRule $filepath
                    #Get hiding rules (only concerned with hiding rules that are registry keys)
                    $notRefHideRules = $notRefRule | Where-Object { $_.HidingType -eq 'FolderOrKey' -and $_.FullName -like "HKLM*" } | Select-Object -ExpandProperty FullName
                    $diffRule += $notRefHideRules
                }
            }

            #get rid of dupes between the rest of the files
            $uniqueDiffRule = $diffRule | Group-Object | Select-Object -ExpandProperty Name

            #Add all together
            $refAndDiff = $refRule + $uniqueDiffRule

            #Get Dupes between current file and rest of files
            $dupes = $refAndDiff  | Group-Object | Where-Object { $_.Count -gt 1 } | Select-Object -ExpandProperty Name

            #remove dupes from old rule list
            $newRules = $rules | Where-Object {$dupes -notcontains $_.FullName }

            $newRuleFileName = Join-Path $OutputPath ($baseFileName + '_Hiding' + '.fxr')

            $newRedirectFileName = Join-Path $OutputPath ($baseFileName + '_Redirect' + '.fxr')

            $newRules | Set-FslRule -RuleFilePath $newRuleFileName

            $newRedirect = $dupes | Select-Object -Property @{n = 'FullName'; e = {$_}},
            @{n = 'RedirectDestPath'; e = { "HKLM\Software\FSLogix\Redirect\$($baseFileName)\$($_.TrimStart('HKLM\'))"}},
            @{n = 'RedirectType'; e = {'FolderOrKey'}}

            $newRedirect | Set-FslRule -RuleFilePath $newRedirectFileName -RedirectType FolderOrKey


        }

    } #Process
    END {} #End
}  #function Compare-FslRuleFile

function Get-FslAssignment {
    [CmdletBinding()]

    Param (
        [Parameter(
            Position = 0,
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [System.String]$Path
    )

    BEGIN {
        Set-StrictMode -Version Latest
    } # Begin
    PROCESS {
        if (-not (Test-Path $Path)) {
            Write-Error "$Path not found."
            exit
        }

        #Grab txt file contents apart from first line
        $lines = Get-Content -Path $Path | Select-Object -Skip 1

        foreach ($line in $lines) {

            #If line matches tab separated data with 5 columns.
            if ( $line -match "([^\t]*\t){5}" ) {
                #Create a powershell object from the columns
                $lineObj = $line | ConvertFrom-String -Delimiter `t -PropertyNames FlagsDec, IdString, DistinguishedName, FriendlyName, AssignedTime, UnAssignedTime
                #ConvertFrom-String converts the hex value in flag to decimal, need to convert back to a hex string. Add in the comment and output it.
                $assignment = $lineObj | Select-Object -Property  IdString, DistinguishedName, FriendlyName, AssignedTime, UnAssignedTime, @{n = 'Flags'; e = {'0x' + "{0:X8}" -f $lineObj.FlagsDec}}

                $poshFlags = $assignment.Flags | ConvertFrom-FslAssignmentCode

                if ($poshFlags.PSObject.Properties -contains 'java') {
                    Write-Error 'Please use the cmdlet Get-FslJavaAssignment to get assignments for java files'
                    exit
                }

                $output = [PSCustomObject]@{
                    PSTypeName          = "FSLogix.Assignment"
                    RuleSetApplies      = switch ( $true ) {
                        $poshFlags.Remove { $false }
                        $poshFlags.Apply { $true }
                    }
                    UserName            = if ( $poshFlags.User ) { $assignment.IdString } else { $null }
                    GroupName           = if ( $poshFlags.Group ) { $assignment.FriendlyName } else { $null }
                    ADDistinguisedName  = if ( $poshFlags.Group ) { $assignment.DistinguishedName } else {$null}
                    WellKnownSID        = if ( $poshFlags.Group ) { $assignment.IdString } else { $null }
                    ProcessName         = if ( $poshFlags.Process ) { $assignment.IdString } else { $null }
                    IncludeChildProcess = if ( $poshFlags.Process ) { $poshFlags.ApplyToProcessChildren } else { $null }
                    IPAddress           = if ( $poshFlags.Network ) { $assignment.IdString } else { $null }
                    ComputerName        = if ( $poshFlags.Computer ) { $assignment.IdString } else { $null }
                    OU                  = if ( $poshFlags.ADDistinguishedName ) { $assignment.IdString } else { $null }
                    EnvironmentVariable = if ( $poshFlags.EnvironmentVariable ) { $assignment.IdString } else { $null }
                    AssignedTime        = if ( $poshFlags.EnvironmentVariable ) {
                        if ($assignment.AssignedTime -ne 0) {
                            [DateTime]::FromFileTime($assignment.AssignedTime)
                        }
                        else {
                            0
                        }
                    }
                    else { 0 }
                    UnAssignedTime      = if ( $poshFlags.EnvironmentVariable ) {
                        if ($assignment.UnAssignedTime -ne 0) {
                            [DateTime]::FromFileTime($assignment.UnAssignedTime)
                        }
                        else {
                            0
                        }
                    }
                    else { 0 }
                }

                Write-Output $output
            } #if
        } #foreach
    } #Process
    END {} #End
}  #function Get-FslAssignment

function Get-FslLicenseDay {
    [CmdletBinding()]

    Param (
        [Parameter(
            Position = 0,
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [Alias('AssignmentFilePath')]
        [System.String]$Path
    )

    BEGIN {
        Set-StrictMode -Version Latest
    } # Begin
    PROCESS {
        if (-not (Test-Path $Path)) {
            Write-Error "$Path not found."
            break
        }

        If ((Get-ChildItem -Path $Path).Extension -ne '.fxa') {
            Write-Warning 'Assignment file extension should be .fxa'
        }

        $firstLine = Get-Content -Path $Path -TotalCount 1

        try {
            [int]$licenseDay = $firstLine.Split("`t")[-1]
        }
        catch {
            Write-Error "Bad data on first line of $Path"
            break
        }

        $output = [pscustomobject]@{
            LicenseDay = $licenseDay
        }

        Write-Output $output

    } #Process
    END {} #End
}  #function Get-FslLicenseDay

function Get-FslRule {
    [CmdletBinding()]

    Param (
        [Parameter(
            Position = 0,
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [System.String]$Path
    )

    BEGIN {
        Set-StrictMode -Version Latest
    } # Begin
    PROCESS {
        if (-not (Test-Path $Path)) {
            Write-Error "$Path not found."
            exit
        }
        #Grab txt file contents apart from first line
        $lines = Get-Content -Path $Path | Select-Object -Skip 1

        foreach ($line in $lines) {
            switch ($true) {
                #Grab comment if this line is one.
                $line.StartsWith('##') {
                    $comment = $line.TrimStart('#')
                    break
                }
                #If line matches tab separated data with 5 columns.
                { $line -match "([^\t]*\t){5}" } {
                    #Create a powershell object from the columns
                    $lineObj = $line | ConvertFrom-String -Delimiter `t -PropertyNames SrcParent, Src, DestParent, Dest, FlagsDec, Binary
                    #ConvertFrom-String converts the hex value in flag to decimal, need to convert back to a hex string. Add in the comment and output it.
                    $rulePlusComment = $lineObj | Select-Object -Property SrcParent, Src, DestParent, Dest, @{n = 'Flags'; e = {'0x' + "{0:X8}" -f $lineObj.FlagsDec}}, Binary, @{n = 'Comment'; e = {$comment}}

                    $poshFlags = $rulePlusComment.Flags | ConvertFrom-FslRuleCode
                    if ($rulePlusComment.DestParent) {
                        $destPath = try {
                            (Join-Path $rulePlusComment.DestParent $rulePlusComment.Dest -ErrorAction Stop).TrimEnd('\')
                        }
                        catch {
                            [system.io.fileinfo]($rulePlusComment.DestParent.TrimEnd('\', '/') + '\' + $rulePlusComment.Dest.TrimStart('\', '/').TrimEnd('\'))
                        }
                    }
                    $fullnameJoin = try {
                        (Join-Path $rulePlusComment.SrcParent $rulePlusComment.Src -ErrorAction Stop).TrimEnd('\')
                    }
                    catch {
                        [system.io.fileinfo]($rulePlusComment.SrcParent.TrimEnd('\', '/') + '\' + $rulePlusComment.Src.TrimStart('\', '/')).TrimEnd('\')
                    }

                    $output = [PSCustomObject]@{
                        PSTypeName       = "FSLogix.Rule"
                        FullName         = $fullnameJoin

                        HidingType       = if ($poshFlags.Hiding -or $poshFlags.HideFont -or $poshFlags.Printer) {
                            switch ( $true ) {
                                $poshFlags.HideFont {'Font'; break}
                                $poshFlags.Printer {'Printer'; break}
                                $poshFlags.FolderOrKey {'FolderOrKey'; break}
                                $poshFlags.FileOrValue {'FileOrValue'; break}
                            }
                        }
                        else { $null }
                        RedirectDestPath = if ($poshFlags.Redirect) { $destPath } else {$null}
                        RedirectType     = if ($poshFlags.Redirect) {
                            switch ( $true ) {
                                $poshFlags.FolderOrKey {'FolderOrKey'; break}
                                $poshFlags.FileOrValue {'FileOrValue'; break}
                            }
                        }
                        else { $null }
                        CopyObject       = if ($poshFlags.CopyObject) { $poshFlags.CopyObject } else {$null}
                        DiskFile         = if ($poshFlags.VolumeAutoMount) { $destPath } else {$null}
                        Binary           = $rulePlusComment.Binary
                        Data             = $null
                        Comment          = $rulePlusComment.Comment
                        #Flags            = $rulePlusComment.Flags
                    }

                    Write-Output $output
                    break

                }
                Default {
                    Write-Error "Rule file element: $line Does not match a comment or a rule format"
                }
            }
        }
    } #Process
    END {} #End
}  #function Get-FslRule

function Remove-FslAssignment {
    [CmdletBinding(SupportsShouldProcess = $true)]

    Param (
        [Parameter(
            Position = 0,
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [alias('AssignmentFilePath')]
        [System.String]$Path,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [alias('FullName')]
        [System.String]$Name,


        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$Force
    )

    BEGIN {
        Set-StrictMode -Version Latest
    } # Begin
    PROCESS {

        If (-not (Test-Path -Path $Path)) {
            Write-Error "$Path Not found"
            break
        }

        if ($Path -notlike "*.fxa") {
            Write-Warning 'Assignment files should have an fxa filename extension'
        }

        $licenceDay = (Get-FslLicenseDay -Path $Path).LicenseDay

        $assignments = Get-FslAssignment -Path $Path



        switch ($true) {
            {$assignments.UserName -contains $Name} {
                $lines = $assignments | Where-Object {$_.Username -eq $Name}
                foreach ($line in $lines) {
                    If ($PSCmdlet.ShouldProcess("UserName Assignment $Name")) {
                        Remove-FslLine -Path $Path -Category Username -Name $Name -Type Assignment
                    }
                }
            }
            {$assignments.GroupName -contains $Name} {
                $lines = $assignments | Where-Object {$_.GroupName -eq $Name}
                foreach ($line in $lines) {
                    If ($PSCmdlet.ShouldProcess("GroupName Assignment $Name")) {
                        Remove-FslLine -Path $Path -Category GroupName -Name $Name -Type Assignment
                    }
                }
            }
            {$assignments.ProcessName -contains $Name} {
                $lines = $assignments | Where-Object {$_.ProcessName -eq $Name}
                foreach ($line in $lines) {
                    If ($PSCmdlet.ShouldProcess("ProcessName Assignment $Name")) {
                        Remove-FslLine -Path $Path -Category ProcessName -Name $Name -Type Assignment
                    }
                }
            }
            {$assignments.IPAddress -contains $Name} {
                $lines = $assignments | Where-Object {$_.IPAddress -eq $Name}
                foreach ($line in $lines) {
                    If ($PSCmdlet.ShouldProcess("IPAddress Assignment $Name")) {
                        Remove-FslLine -Path $Path -Category IPAddress -Name $Name -Type Assignment
                    }
                }
            }
            {$assignments.ComputerName -contains $Name} {
                $lines = $assignments | Where-Object {$_.ComputerName -eq $Name}
                foreach ($line in $lines) {
                    If ($PSCmdlet.ShouldProcess("ComputerName Assignment $Name")) {
                        Remove-FslLine -Path $Path -Category ComputerName -Name $Name -Type Assignment
                    }
                }
            }
            {$assignments.OU -contains $Name} {
                $lines = $assignments | Where-Object {$_.OU -eq $Name}
                foreach ($line in $lines) {
                    If ($PSCmdlet.ShouldProcess("OU Assignment $Name")) {
                        Remove-FslLine -Path $Path -Category OU -Name $Name -Type Assignment
                    }
                }
            }
            {$assignments.EnvironmentVariable -contains $Name} {
                $lines = $assignments | Where-Object {$_.EnvironmentVariable -eq $Name}

                foreach ($line in $lines) {

                    if (-not $line.AssignedTime -eq 0) {
                        $unassignMinimum = $line.AssignedTime.AddDays($licenceDay)
                    }
                    $now = Get-Date

                    switch ($true) {

                        {$line.AssignedTime -eq 0} {
                            If ($PSCmdlet.ShouldProcess("Environment Variable Assignment $Name")) {
                                Remove-FslLine -Path $Path -Category EnvironmentVariable -Name $Name -Type Assignment
                            }
                            break
                        }
                        {$licenceDay -ne 0 -and
                            $line.AssignedTime -ne 0 -and
                            $unassignMinimum -gt $now -and
                            $Force -eq $false
                        } {
                            #If check for license time has failed and force isn't present, throw an error.
                            $daysLeft = ($unassignMinimum - $line.AssignedTime).Days
                            Write-Error "License agreement violation detected $daysLeft days left out of $licenceDay days before license can be reassigned."
                            break
                        }

                        Default {
                            If ($PSCmdlet.ShouldProcess("Environment Variable Assignment $Name")) {
                                Remove-FslLine -Path $Path -Category EnvironmentVariable -Name $Name -Type Assignment
                                $line.UnAssignedTime = Get-Date
                                $line | Add-FslAssignment -Path $Path
                            }
                        }
                    }
                }
            }

            Default {}
        }

        $licenceDay | Set-FslLicenseDay -Path $Path

    } #Process
    END {} #End
}  #function Remove-FslAssignment

function Set-FslAssignment {

    <#
        .SYNOPSIS
            Sets the content of a FSLogix Rule assignment file.

        .DESCRIPTION
            This function can set an FSLogix assignment file contents, the assignment file should have the same basename as the matching rule file.
            This will overwrite the contents of an existing file.

        .PARAMETER AssignmentFilePath
            The Target file path to set the assignment within
        .PARAMETER RuleSetApplies
            This determines whether a ruleset does or does not apply to users/groups/processes etc.  For instance when using a Hiding rule, applying that hiding rule to users will hide the file from the users assigned to it when applied.
        .PARAMETER UserName
            If you wish to tie down the rule to an individual user use theier unsername in this parameter.  Groupname is more usual for assignments however
        .PARAMETER GroupName
            Use this to tie the assignment of the rule to a specific group
        .PARAMETER WellKnownSID
            The Well Known SID for groups such as Domain Admins are useful for cross-language assignments, if you use a group with a well known SID in the group name parameter this will be automatically filled out, so mostly useful for pipeline input.
        .PARAMETER ADDistinguisedName
            Full Distinguished name of AD component
        .PARAMETER ProcessName
            Process name for the rule assignment, mostly used for redirect rules
        .PARAMETER IncludeChildProcess
            If Process name is stated you can optionally include chile prcesses (recommended)
        .PARAMETER ProcessId
            If you know process ID, but not name, used for troubleshooting mainly
        .PARAMETER IPAddress
            Enter the IPv4 or IPv6 address. Partial strings are allowed. For example, if you enter 192.168, an address of 192.168.0.1 will be considered to match.
        .PARAMETER ComputerName
            Enter the Full Distinguished Name of the computer object, or the computer name (wildcards accepted). Must be in the format ComputerName@Domain
        .PARAMETER OU
            You can specify an Active Directory Container and the assignment will be effective for all of the objects in that container. Enter the Full Distinguished Name of the container.
        .PARAMETER EnvironmentVariable
            By Specifying an environment variable, you can customize rules in various other ways. A very useful example for this option is when using it with RDSH, XenApp, or other remote sessions. You can use the Environment Variable CLIENTNAME to limit visibility to the device being used to access the RDSH or XenApp system.
            The environment variables that are supported are the ones that are present when the user's session is created. Environment variables set during logon are not supported.
        .EXAMPLE
            A sample command that uses the function or script, optionaly followed
            by sample output and a description. Repeat this keyword for each example.
    #>

    [CmdletBinding()]
    Param (

        [Parameter(
            Position = 1,
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [Alias('AssignmentFilePath')]
        [System.String]$Path,

        [Parameter(
            ParameterSetName = 'User',
            ValuefromPipelineByPropertyName = $true
        )]
        [Parameter(
            ParameterSetName = 'Group',
            ValuefromPipelineByPropertyName = $true
        )]
        [Parameter(
            ParameterSetName = 'Executable',
            ValuefromPipelineByPropertyName = $true
        )]
        [Parameter(
            ParameterSetName = 'Network',
            ValuefromPipelineByPropertyName = $true
        )]
        [Parameter(
            ParameterSetName = 'Computer',
            ValuefromPipelineByPropertyName = $true
        )]
        [Parameter(
            ParameterSetName = 'OU',
            ValuefromPipelineByPropertyName = $true
        )]
        [Parameter(
            ParameterSetName = 'EnvironmentVariable',
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$RuleSetApplies,

        [Parameter(
            ParameterSetName = 'User',
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$UserName,

        [Parameter(
            ParameterSetName = 'Group',
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$GroupName,

        [Parameter(
            ParameterSetName = 'Group',
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$WellKnownSID,

        [Parameter(
            ParameterSetName = 'User',
            ValuefromPipelineByPropertyName = $true
        )]
        [Parameter(
            ParameterSetName = 'Group',
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$ADDistinguisedName,

        [Parameter(
            ParameterSetName = 'Executable',
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$ProcessName,

        [Parameter(
            ParameterSetName = 'Executable',
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$IncludeChildProcess,

        [Parameter(
            ParameterSetName = 'Network',
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$IPAddress,

        [Parameter(
            ParameterSetName = 'Computer',
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [ValidatePattern(".*@.*")]
        [System.String]$ComputerName,

        [Parameter(
            ParameterSetName = 'OU',
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$OU,

        [Parameter(
            ParameterSetName = 'EnvironmentVariable',
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [ValidatePattern(".*=.*")]
        [System.String]$EnvironmentVariable,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$PassThru,

        [Parameter(
            ParameterSetName = 'AssignmentObjectPipeline',
            ValuefromPipeline = $true,
            ValuefromPipelineByPropertyName = $true
        )]
        [PSTypeName('FSLogix.Assignment')]$InputObject
    )
    BEGIN {
        Set-StrictMode -Version Latest
        $version = 1
        $minimumLicenseAssignedTime = 0
        $setContent = $true

    } # Begin
    PROCESS {

        #check file has correct filename extension
        if ($Path -notlike "*.fxa") {
            Write-Warning 'Assignment files should have an fxa extension'
        }

        #Add first line if pipeline input
        If ($setContent) {
            Set-Content -Path $Path -Value "$version`t$minimumLicenseAssignedTime" -Encoding Unicode -ErrorAction Stop -WhatIf:$false
            Add-FslAssignment @PSBoundParameters
            $setContent = $false
        }
        else {
            Add-FslAssignment @PSBoundParameters
        }

    } #Process
    END {
    } #End
}  #function Set-FslAssignment

function Set-FslLicenseDay {

    [CmdletBinding()]

    Param (
        [Parameter(
            Position = 0,
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [Alias('AssignmentFilePath')]
        [System.String]$Path,

        [Parameter(
            Position = 1,
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [int]$LicenseDay

    )

    BEGIN {
        Set-StrictMode -Version Latest
        $version = 1
    } # Begin
    PROCESS {

        if (-not (Test-Path $Path)) {
            Write-Error "$Path not found."
            break
        }

        If ((Get-ChildItem -Path $Path).Extension -ne '.fxa') {
            Write-Warning 'Assignment file extension should be .fxa'
        }

        $content = Get-Content -Path $Path | Select-Object -Skip 1

        Set-Content -Path $Path -Value "$version`t$LicenseDay" -Encoding Unicode -WhatIf:$false

        Add-Content -Path $Path -Value $content -Encoding Unicode -WhatIf:$false

    } #Process
    END {} #End
}  #function Set-FslLicenseDay

function Set-FslRule {
    [CmdletBinding()]

    Param (

        [Parameter(
            Position = 1,
            Mandatory = $true,
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$RuleFilePath,

        [Parameter(
            ParameterSetName = 'Hiding',
            Position = 2,
            ValueFromPipeline = $true,
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [Parameter(
            ParameterSetName = 'Redirect',
            Position = 2,
            ValueFromPipeline = $true,
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [Parameter(
            ParameterSetName = 'AppContainer',
            Position = 2,
            ValueFromPipeline = $true,
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [Parameter(
            ParameterSetName = 'SpecifyValue',
            Position = 2,
            ValueFromPipeline = $true,
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [Alias('Name')]
        [System.String]$FullName,

        [Parameter(
            ParameterSetName = 'Hiding',
            Mandatory = $true,
            Position = 3,
            ValuefromPipelineByPropertyName = $true
        )]
        [ValidateSet('FolderOrKey', 'FileOrValue', 'Font', 'Printer')]
        [System.String]$HidingType,

        [Parameter(
            ParameterSetName = 'Redirect',
            Mandatory = $true,
            Position = 6,
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$RedirectDestPath,

        [Parameter(
            ParameterSetName = 'Redirect',
            Mandatory = $true,
            Position = 7,
            ValuefromPipelineByPropertyName = $true
        )]
        [ValidateSet('FolderOrKey', 'FileOrValue')]
        [System.String]$RedirectType,

        [Parameter(
            ParameterSetName = 'Redirect',
            Position = 8,
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$CopyObject,

        [Parameter(
            ParameterSetName = 'AppContainer',
            Mandatory = $true,
            Position = 9,
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$DiskFile,

        [Parameter(
            ParameterSetName = 'SpecifyValue',
            Mandatory = $true,
            Position = 10,
            ValuefromPipelineByPropertyName = $true
        )]
        [Alias('Binary')]
        [System.String]$Data,

        [Parameter(
            Position = 11,
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$Comment = 'Created By PowerShell Script',

        [Parameter(
            Position = 13,
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$Passthru,

        [Parameter(
            ParameterSetName = 'RuleObjectPipeline',
            Position = 14,
            ValuefromPipeline = $true,
            ValuefromPipelineByPropertyName = $true
        )]
        [PSTypeName('FSLogix.Rule')]$RuleObject
    )


    BEGIN {
        Set-StrictMode -Version Latest
        $version = 1
        $setContent = $true
    } # Begin
    PROCESS {

        #check file has correct filename extension
        if ($RuleFilePath -notlike "*.fxr") {
            Write-Warning 'The Rule file should have an fxr extension'
        }

        #Add first line if pipeline input
        If ($setContent) {
            Set-Content -Path $RuleFilePath -Value $version -Encoding Unicode -ErrorAction Stop
            Add-FslRule @PSBoundParameters
            $setContent = $false
        }
        else {
            Add-FslRule @PSBoundParameters
        }
    } #Process
    END {} #End
}  #function Set-FslRule

function ConvertFrom-FslAssignmentCode {
    [CmdletBinding()]

    Param (
        [Parameter(
            Position = 0,
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [Int]$AssignmentCode
    )

    BEGIN {
        Set-StrictMode -Version Latest
        $Apply = 0x0001
        $Remove = 0x0002
        $User = 0x0004
        $Process = 0x0008
        $Group = 0x0010
        $Network = 0x0020
        $Computer = 0x0040
        $ADDistinguishedName = 0x0080
        $ApplyToProcessChildren = 0x0100
        #$ProcessID                  = 0x0200
        $EnvironmentVariable = 0x2000
        #$MandatoryLevelShift        = 10
        #$MandatoryLevelMask         = 0x1C00

    } # Begin
    PROCESS {
        $output = [PSCustomObject]@{
            'Apply'                  = if ( $AssignmentCode -band $Apply ) { $true } else { $false }
            'Remove'                 = if ( $AssignmentCode -band $Remove ) { $true } else { $false }
            'User'                   = if ( $AssignmentCode -band $User ) { $true } else { $false }
            'Process'                = if ( $AssignmentCode -band $Process ) { $true } else { $false }
            'Group'                  = if ( $AssignmentCode -band $Group ) { $true } else { $false }
            'Network'                = if ( $AssignmentCode -band $Network ) { $true } else { $false }
            'Computer'               = if ( $AssignmentCode -band $Computer ) { $true } else { $false }
            'ADDistinguishedName'    = if ( $AssignmentCode -band $ADDistinguishedName ) { $true } else { $false }
            'ApplyToProcessChildren' = if ( $AssignmentCode -band $ApplyToProcessChildren ) { $true } else { $false }
            #'ProcessId'              = if ( $AssignmentCode -band $ProcessID ) { $true } else { $false } #Can't get the GUI to produce a pid code
            'EnvironmentVariable'    = if ( $AssignmentCode -band $EnvironmentVariable ) { $true } else { $false }

            #The Mandatory bits are in the original code, but not used
            #'MandatoryLevelShift'    = if ( $AssignmentCode -band $MandatoryLevelShift ) { $true } else { $false }
            #'MandatoryLevelMask'     = if ( $AssignmentCode -band $MandatoryLevelMask ) { $true } else { $false }
        }

        Write-Output $output

    } #Process
    END {} #End
}  #function ConvertFrom-FslAssignmentCode

function ConvertFrom-FslRuleCode {
    [CmdletBinding()]

    Param (
        [Parameter(
            Position = 0,
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [Int]$RuleCode
    )

    BEGIN {
        Set-StrictMode -Version Latest
        $FRX_RULE_SRC_IS_A_DIR_OR_KEY = 0x00000001
        $FRX_RULE_SRC_IS_A_FILE_OR_VALUE = 0x00000002
        $FRX_RULE_SHOULD_COPY_FILE = 0x00000010
        $FRX_RULE_TYPE_REDIRECT = 0x00000100
        $FRX_RULE_TYPE_HIDING = 0x00000200
        $FRX_RULE_TYPE_HIDE_PRINTER = 0x00000400
        $FRX_RULE_TYPE_SPECIFIC_DATA = 0x00000800 #Specific Value Rule
        $FRX_RULE_TYPE_JAVA = 0x00001000
        $FRX_RULE_TYPE_VOLUME_AUTOMOUNT = 0x00002000
        $FRX_RULE_TYPE_HIDE_FONT = 0x00004000
    } # Begin

    PROCESS {

        switch ($true) {
            { $RuleCode -band $FRX_RULE_SRC_IS_A_DIR_OR_KEY } { $folderOrKey = $true }
            { -not ( $RuleCode -band $FRX_RULE_SRC_IS_A_DIR_OR_KEY ) } { $folderOrKey = $false}
            { $RuleCode -band $FRX_RULE_SRC_IS_A_FILE_OR_VALUE } {$fileOrValue = $true}
            { -not ( $RuleCode -band $FRX_RULE_SRC_IS_A_FILE_OR_VALUE ) } { $fileOrValue = $false }
            { $RuleCode -band $FRX_RULE_SHOULD_COPY_FILE } { $copyObject = $true }
            { -not ( $RuleCode -band $FRX_RULE_SHOULD_COPY_FILE ) } { $copyObject = $false }
            { $RuleCode -band $FRX_RULE_TYPE_REDIRECT } { $redirect = $true}
            { -not ( $RuleCode -band $FRX_RULE_TYPE_REDIRECT ) } { $redirect = $false }
            { $RuleCode -band $FRX_RULE_TYPE_HIDING } { $hiding = $true}
            { -not ( $RuleCode -band $FRX_RULE_TYPE_HIDING ) } { $hiding = $false }
            { $RuleCode -band $FRX_RULE_TYPE_HIDE_PRINTER } { $hidePrinter = $true }
            { -not ( $RuleCode -band $FRX_RULE_TYPE_HIDE_PRINTER ) } { $hidePrinter = $false}
            { $RuleCode -band $FRX_RULE_TYPE_SPECIFIC_DATA } { $specificData = $true }
            { -not ( $RuleCode -band $FRX_RULE_TYPE_SPECIFIC_DATA ) } { $specificData = $false }
            { $RuleCode -band $FRX_RULE_TYPE_JAVA } { $java = $true }
            { -not ( $RuleCode -band $FRX_RULE_TYPE_JAVA ) } { $java = $false }
            { $RuleCode -band $FRX_RULE_TYPE_VOLUME_AUTOMOUNT } { $volumeAutoMount = $true}
            { -not ( $RuleCode -band $FRX_RULE_TYPE_VOLUME_AUTOMOUNT ) } { $volumeAutoMount = $false }
            { $RuleCode -band $FRX_RULE_TYPE_HIDE_FONT } { $font = $true }
            { -not ( $RuleCode -band $FRX_RULE_TYPE_HIDE_FONT ) } { $font = $false }
            default {}
        } #Switch

        $outObject = [PSCustomObject]@{
            'FolderOrKey'     = $folderOrKey
            'FileOrValue'     = $fileOrValue
            'CopyObject'      = $copyObject
            'Redirect'        = $redirect
            'Hiding'          = $hiding
            'Printer'         = $hidePrinter
            'SpecificData'    = $specificData
            'Java'            = $java
            'VolumeAutoMount' = $volumeAutoMount
            'HideFont'        = $font
        }
        Write-Output $outObject
    } #Process
    END {} #End
}  #function ConvertFrom-FslRuleCode

function ConvertTo-FslAssignmentCode {
    [CmdletBinding()]

    Param (
        [Parameter(
            Position = 0,
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$Apply,

        [Parameter(
            Position = 1,
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$Remove,

        [Parameter(
            Position = 2,
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$User,

        [Parameter(
            Position = 3,
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$Process,

        [Parameter(
            Position = 4,
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$Group,

        [Parameter(
            Position = 5,
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$Network,

        [Parameter(
            Position = 6,
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$Computer,

        [Parameter(
            Position = 7,
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$ADDistinguishedName,

        [Parameter(
            Position = 8,
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$ApplyToProcessChildren,

        [Parameter(
            Position = 9,
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$ProcessId,

        [Parameter(
            Position = 10,
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$EnvironmentVariable
    )

    BEGIN {
        Set-StrictMode -Version Latest
        $ApplyBit = 0x0001
        $RemoveBit = 0x0002
        $UserBit = 0x0004
        $ProcessBit = 0x0008
        $GroupBit = 0x0010
        $NetworkBit = 0x0020
        $ComputerBit = 0x0040
        $ADDistinguishedNameBit = 0x0080
        $ApplyToProcessChildrenBit = 0x0100
        #$PidBit = 0x0200
        $EnvironmentVariableBit = 0x2000

        #$MandatoryLevelMaskBit = 0x1C00
        #$MandatoryLevelShiftBit = 10
    } # Begin
    PROCESS {
        $codeToOutput = 0
        switch ($true) {
            $Apply { $codeToOutput = $codeToOutput -bor $ApplyBit }
            $Remove { $codeToOutput = $codeToOutput -bor $RemoveBit }
            $User { $codeToOutput = $codeToOutput -bor $UserBit }
            $Process { $codeToOutput = $codeToOutput -bor $ProcessBit }
            $Group { $codeToOutput = $codeToOutput -bor $GroupBit }
            $Network { $codeToOutput = $codeToOutput -bor $NetworkBit }
            $Computer { $codeToOutput = $codeToOutput -bor $ComputerBit }
            $ADDistinguishedName { $codeToOutput = $codeToOutput -bor $ADDistinguishedNameBit }
            $ApplyToProcessChildren { $codeToOutput = $codeToOutput -bor $ApplyToProcessChildrenBit }
            #$ProcessId { $codeToOutput = $codeToOutput -bor $PidBit } #Can't get the GUI to produce a pid code
            $EnvironmentVariable { $codeToOutput = $codeToOutput -bor $EnvironmentVariableBit }

            #The Mandatory bits are in the original code, but not used
            #$MandatoryLevelMask { $codeToOutput = $codeToOutput -bor $MandatoryLevelMaskBit }
            #$MandatoryLevelShift { $codeToOutput = $codeToOutput -bor $MandatoryLevelShiftBit }
        }

        #convert code to hex string so it doesn't get outputted as an integer
        $formattedCode = "0x{0:X8}" -f $codeToOutput

        Write-Output $formattedCode.ToLower()

    } #Process
    END {} #End
}  #function ConvertTo-FslAssignmentCode

function ConvertTo-FslRuleCode {
    [CmdletBinding()]

    Param (
        [Parameter(
            Position = 0,
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$FolderOrKey,

        [Parameter(
            Position = 1,
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$FileOrValue,

        <#
        [Parameter(
            Position = 2,
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$ContainsUserVar,
        #>

        [Parameter(
            Position = 3,
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$CopyObject,

        <#
        [Parameter(
            Position = 4,
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$Persistent,
        #>

        [Parameter(
            Position = 5,
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$Redirect,

        [Parameter(
            Position = 6,
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$Hiding,

        [Parameter(
            Position = 7,
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$Printer,

        [Parameter(
            Position = 8,
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$SpecificData,

        [Parameter(
            Position = 9,
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$Java,

        [Parameter(
            Position = 10,
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$VolumeAutoMount,

        [Parameter(
            Position = 11,
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$HideFont

        <#
        [Parameter(
            Position = 12,
            ValuefromPipelineByPropertyName = $true
        )]
        [Switch]$Mask
        #>
    )

    BEGIN {
        Set-StrictMode -Version Latest
        $FRX_RULE_SRC_IS_A_DIR_OR_KEY = 0x00000001
        $FRX_RULE_SRC_IS_A_FILE_OR_VALUE = 0x00000002
        #$FRX_RULE_CONTAINS_USER_VARS = 0x00000008
        $FRX_RULE_SHOULD_COPY_FILE = 0x00000010
        $FRX_RULE_IS_PERSISTANT = 0x00000020
        $FRX_RULE_TYPE_REDIRECT = 0x00000100
        $FRX_RULE_TYPE_HIDING = 0x00000200
        $FRX_RULE_TYPE_HIDE_PRINTER = 0x00000400
        $FRX_RULE_TYPE_SPECIFIC_DATA = 0x00000800
        $FRX_RULE_TYPE_JAVA = 0x00001000
        $FRX_RULE_TYPE_VOLUME_AUTOMOUNT = 0x00002000
        $FRX_RULE_TYPE_HIDE_FONT = 0x00004000
    } # Begin
    PROCESS {
        $codeToOutput = 0
        #Persistent is always true except if Java is present so no need to pass in a parameter
        if ($java) {
            $persistent = $false
        }
        else {
            $persistent = $true
        }

        switch ($true) {
            $FolderOrKey { $codeToOutput = $codeToOutput -bor $FRX_RULE_SRC_IS_A_DIR_OR_KEY }
            $FileOrValue { $codeToOutput = $codeToOutput -bor $FRX_RULE_SRC_IS_A_FILE_OR_VALUE }
            $CopyObject { $codeToOutput = $codeToOutput -bor $FRX_RULE_SHOULD_COPY_FILE }
            $Persistent { $codeToOutput = $codeToOutput -bor $FRX_RULE_IS_PERSISTANT }
            $Redirect { $codeToOutput = $codeToOutput -bor $FRX_RULE_TYPE_REDIRECT }
            $Hiding { $codeToOutput = $codeToOutput -bor $FRX_RULE_TYPE_HIDING }
            $Printer { $codeToOutput = $codeToOutput -bor $FRX_RULE_TYPE_HIDE_PRINTER }
            $SpecificData { $codeToOutput = $codeToOutput -bor $FRX_RULE_TYPE_SPECIFIC_DATA }
            $Java { $codeToOutput = $codeToOutput -bor $FRX_RULE_TYPE_JAVA }
            $VolumeAutomount { $codeToOutput = $codeToOutput -bor $FRX_RULE_TYPE_VOLUME_AUTOMOUNT }
            $HideFont { $codeToOutput = $codeToOutput -bor $FRX_RULE_TYPE_HIDE_FONT }
        }

        #convert code to hex string so it doesn't get outputted as an integer
        $formattedCode = "0x{0:X8}" -f $codeToOutput

        Write-Output $formattedCode
    } #Process
    END {} #End
}  #function ConvertTo-FslRuleCode

function Remove-FslLine {
    [CmdletBinding()]

    Param (
        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$Path,
        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$Category,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$Name,
        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [ValidateSet('Assignment', 'Rule')]
        [System.String]$Type
    )

    BEGIN {
        Set-StrictMode -Version Latest
    } # Begin
    PROCESS {

        switch ($Type) {
            Assignment {
                Get-FslAssignment $Path | Where-Object {$_.$Category -ne $Name} | Set-FslAssignment $Path
            }
            Rule {
                Get-FslRule $Path | Where-Object {$_.$Category -ne $Name} | Set-FslRule $Path
            }
            Default {}
        }

    } #Process
    END {} #End
}  #function Remove-FslLine

Export-ModuleMember -Function Add-FslAssignment, Add-FslRule, Compare-FslFilePath, Compare-FslRuleFile, Get-FslAssignment, Get-FslLicenseDay, Get-FslRule, Remove-FslAssignment, Set-FslAssignment, Set-FslLicenseDay, Set-FslRule