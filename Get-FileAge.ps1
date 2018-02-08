Function Get-FileAge {
    <#
        .SYNOPSIS
            Gets file age and owner from a specified path.
        
        .DESCRIPTION
            Retrieves the file age (with Last Write Time, Last Modified Time) and Owner from files in a specified path.


        .NOTES
            Name: Get-FileAge.ps1
            Author: Aaron Parker
            Twitter: @stealthpuppy
        
        .LINK
            http://stealthpuppy.com

        .OUTPUTS
            [System.Array]

        .PARAMETER Path
            Specified a path to one or more location which to scan files.

        .EXAMPLE
            Get-FileAge -Path "\\server\share\folder"

            Description:
            Scans the specified path returns the age and owner for each file.

        .PARAMETER Include
            Gets only the specified items.

        .EXAMPLE
            Get-FileAge -Path "\\server\share\folder" -Include ".vhdx"

            Description:
            Scans the specified path returns the age and owner for each .vhdx file.

    #>
    [CmdletBinding(SupportsShouldProcess=$False)]
    Param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, `
        HelpMessage='Specify a target path, paths or a list of files to scan for age.')]
        [Alias('FullName','PSPath')]
        [string[]]$Path = ".\", 

        [Parameter(Mandatory=$False, ValueFromPipeline=$False, `
        HelpMessage='Gets only the specified items.')]
        [Alias('Filter')]
        [string[]]$Include = "*.*"
    )

    Begin {
        # Measure time taken to gather data
        $StopWatch = [system.diagnostics.stopwatch]::StartNew()

        Write-Verbose "Beginning file age trawling."
        $Files = @()
    }
    Process {
        # For each path in $Path, check that the path exists
        If (Test-Path -Path $Path -IsValid) {

            # Get the item to determine whether it's a file or folder
            If ((Get-Item -Path $Path).PSIsContainer) {

                # Target is a folder, so trawl the folder for files in the target and sub-folders
                Write-Verbose "Getting age for files in folder: $Path"
                $items = Get-ChildItem -Path $Path -Recurse -File -Include $Include
            } Else {

                # Target is a file, so just get metadata for the file
                Write-Verbose "Getting age for file: $Path"
                $items = Get-ChildItem -Path $Path
            }

            # Create an array from what was returned for specific data and sort on file path
            $Files += $items | Select-Object @{Name = "Path"; Expression = {$_.FullName}}, `
                @{Name = "Owner"; Expression = {(Get-Acl -Path $_.FullName).Owner}}, `
                @{Name = "LastAccessTime"; Expression = {$_.LastAccessTime}}, `
                @{Name = "LastWriteTime"; Expression = {$_.LastWriteTime}}
        } Else {
                Write-Error "Path does not exist: $Path"
        }
    }
    End {

        # Return the array of file paths and metadata
        $StopWatch.Stop()
        Write-Verbose "File age trawling complete. Script took $($StopWatch.Elapsed.TotalMilliseconds) ms to complete."
        Return $Files | Sort-Object -Property LastWriteTime
    }
}