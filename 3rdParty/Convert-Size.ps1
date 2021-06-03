Function Convert-Size {
    <#
        .SYNOPSIS
        This powershell script converts computer data sizes between one format and another.
        Optionally you can specify the precision and return only 2 (or any given
        number) of digits after the decimal.

        .DESCRIPTION
        Size conversion in PowerShell is pretty staright forward. If you have a number in
        bytes and want to convert it into MB, or GB, it is as simple as typing 12345/1GB, or
        12345/1MB in PowerShell prompt or script.

        The problem comes when you want to convert a value from something other than bytes to
        something else, and being able to properly handle either base 10 (KB, MB, GB, etc.),
        or base 2 (KiB, MiB, GiB, etc.) size notations correctly.

        Another issue is that you may want to be able to control the precision of the returned
        result (e.g. 0.95 instead of 0.957870483398438).

        This script easily handles conversion from any-to-any (e.g. Bits, Bytes, KB, KiB, MB,
        MiB, etc.) It also has the ability to specify the precision of digits you want to
        recieve as the output.

        International System of Units (SI) Binary and Standard
        http://physics.nist.gov/cuu/Units/binary.html
        https://en.wikipedia.org/wiki/Binary_prefix

        Name Symbol Value Unit Notation English Word
        ——– —— ——————————— —– ——– ————
        Bit (b) : 1 bit
        Bytes (B) : 8 bits ( 2^3 )
        KiloByte (KB) : 1 000 Bytes (10^3 ) Thousand
        KibiByte (KiB): 1 024 Bytes ( 2^10)
        MegaByte (MB) : 1 000 000 Bytes (10^6 ) Million
        MebiByte (MiB): 1 048 576 Bytes ( 2^20)
        GigaByte (GB) : 1 000 000 000 Bytes (10^9 ) Billion
        GibiByte (GiB): 1 073 741 824 Bytes ( 2^30)
        TeraByte (TB) : 1 000 000 000 000 Bytes (10^12) Trillion
        TebiByte (TiB): 1 099 511 627 776 Bytes ( 2^40)
        PetaByte (PB) : 1 000 000 000 000 000 Bytes (10^15) Quadrillion
        PebiByte (PiB): 1 125 899 906 842 624 Bytes ( 2^50)
        ExaByte (EB) : 1 000 000 000 000 000 000 Bytes (10^18) Quintillion
        ExbiByte (EiB): 1 152 921 504 606 850 000 Bytes ( 2^60)
        ZettaByte (ZB) : 1 000 000 000 000 000 000 000 Bytes (10^21) Sextillion
        ZebiByte (ZiB): 1 180 591 620 717 410 000 000 Bytes ( 2^70)
        YottaByte (YB) : 1 000 000 000 000 000 000 000 000 Bytes (10^24) Septillion
        YobiByte (YiB): 1 208 925 819 614 630 000 000 000 Bytes ( 2^80)

        .NOTES
        File Name	: Convert-Size.ps1
        Author	: Techibee posted on July 7, 2014
        Modified By: Void, modified on December 9, 2016

        .LINK
        http://techibee.com/powershell/convert-from-any-to-any-bytes-kb-mb-gb-tb-using-powershell/2376

        .EXAMPLE
        Convert-Size -From KB -To GB -Value 1024
        0.001

        Convert from Kilobyte to Gigabyte (Base 10)
        .EXAMPLE
        Convert-Size -From GB -To GiB -Value 1024
        953.6743

        Convert from Gigabyte (Base 10) to GibiByte (Base 2)
        .EXAMPLE
        Convert-Size -From TB -To TiB -Value 1024 -Precision 2
        931.32

        Convert from Terabyte (Base 10) to Tebibyte (Base 2) with only 2 digits after the decimal
    #>
    [cmdletbinding()]
    param(
        [validateset("b", "B","KB","KiB","MB","MiB","GB","GiB","TB","TiB","PB","PiB","EB","EiB", "ZB", "ZiB", "YB", "YiB")]
        [Parameter(Mandatory=$true)]
        [System.String]$From,

        [validateset("b", "B","KB","KiB","MB","MiB","GB","GiB","TB","TiB","PB","PiB","EB","EiB", "ZB", "ZiB", "YB", "YiB")]
        [Parameter(Mandatory=$true)]
        [System.String]$To,

        [Parameter(Mandatory=$true)]
        [double]$Value,

        [int]$Precision = 4
    )

    # Convert the supplied value to Bytes
    switch -casesensitive ($From) {
        "b" {$value = $value/8 }
        "B" {$value = $Value }
        "KB" {$value = $Value * 1000 }
        "KiB" {$value = $value * 1024 }
        "MB" {$value = $Value * 1000000 }
        "MiB" {$value = $value * 1048576 }
        "GB" {$value = $Value * 1000000000 }
        "GiB" {$value = $value * 1073741824 }
        "TB" {$value = $Value * 1000000000000 }
        "TiB" {$value = $value * 1099511627776 }
        "PB" {$value = $value * 1000000000000000 }
        "PiB" {$value = $value * 1125899906842624 }
        "EB" {$value = $value * 1000000000000000000 }
        "EiB" {$value = $value * 1152921504606850000 }
        "ZB" {$value = $value * 1000000000000000000000 }
        "ZiB" {$value = $value * 1180591620717410000000 }
        "YB" {$value = $value * 1000000000000000000000000 }
        "YiB" {$value = $value * 1208925819614630000000000 }
    }

    # Convert the number of Bytes to the desired output
    switch -casesensitive ($To) {
        "b" {$value = $value * 8}
        "B" {return $value }
        "KB" {$Value = $Value/1000 }
        "KiB" {$value = $value/1024 }
        "MB" {$Value = $Value/1000000 }
        "MiB" {$Value = $Value/1048576 }
        "GB" {$Value = $Value/1000000000 }
        "GiB" {$Value = $Value/1073741824 }
        "TB" {$Value = $Value/1000000000000 }
        "TiB" {$Value = $Value/1099511627776 }
        "PB" {$Value = $Value/1000000000000000 }
        "PiB" {$Value = $Value/1125899906842624 }
        "EB" {$Value = $Value/1000000000000000000 }
        "EiB" {$Value = $Value/1152921504606850000 }
        "ZB" {$value = $value/1000000000000000000000 }
        "ZiB" {$value = $value/1180591620717410000000 }
        "YB" {$value = $value/1000000000000000000000000 }
        "YiB" {$value = $value/1208925819614630000000000 }
    }

    return [Math]::Round($value,$Precision,[MidPointRounding]::AwayFromZero)
}