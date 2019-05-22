function Get-FslAvailableDriveLetter {
 
    Param(
        [Parameter(Position = 0)]
        [Switch]$Next,

        [Parameter(Position = 1)]
        [switch]$Random
    )
    ## Start at D rather than A since A-B are floppy drives and C is used by main operating system.
    $Letters = [char[]](68..90)
    <#$AvailableLetters = New-Object System.Collections.ArrayList
    foreach ($letter in $Letters) {
        $Used_Letter = Get-PsDrive -Name $letter -ErrorAction SilentlyContinue
        if ($null -eq $Used_Letter) {
            $null = $AvailableLetters.add($letter)
        }
    }#>
    $AvailableLetters = $Letters | Where-Object {!(test-path -Path "$($_):")}

    if($null -eq $AvailableLetters){
        Write-Error "Could not find available driveletter."
        exit
    }
    
    if ($PSBoundParameters.ContainsKey("Next")) {
        Write-Output $AvailableLetters | select-object -first 1
    }
    elseif($PSBoundParameters.ContainsKey("Random")) {
        Write-Output $AvailableLetters | get-random
    }else{
        Write-Output $AvailableLetters
    }
 
}