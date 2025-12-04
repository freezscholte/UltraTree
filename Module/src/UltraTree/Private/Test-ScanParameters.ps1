function Test-ScanParameters {
    <#
    .SYNOPSIS
        Validates scan parameters before execution.
    .DESCRIPTION
        Performs input validation on scan parameters and throws descriptive errors.
    .PARAMETER DriveLetter
        The drive letter to scan.
    .PARAMETER MaxDepth
        Maximum folder depth to scan (1-20).
    .PARAMETER Top
        Maximum number of results to return (1-1000).
    .PARAMETER MinDuplicateSize
        Minimum file size for duplicate detection.
    .PARAMETER AllDrives
        Switch indicating all drives should be scanned.
    #>
    param (
        [string]$DriveLetter,
        [int]$MaxDepth,
        [int]$Top,
        [long]$MinDuplicateSize,
        [switch]$AllDrives
    )

    $errors = [System.Collections.Generic.List[string]]::new()

    # Validate drive letter if specified
    if ($DriveLetter -and -not $AllDrives) {
        $drivePath = "${DriveLetter}:\"
        if (-not (Test-Path $drivePath)) {
            $errors.Add("Drive '$DriveLetter' does not exist or is not accessible")
        }
    }

    # Validate MaxDepth
    if ($MaxDepth -lt 1) {
        $errors.Add("MaxDepth must be at least 1 (got: $MaxDepth)")
    }
    if ($MaxDepth -gt 20) {
        $errors.Add("MaxDepth cannot exceed 20 (got: $MaxDepth)")
    }

    # Validate Top
    if ($Top -lt 1) {
        $errors.Add("Top must be at least 1 (got: $Top)")
    }
    if ($Top -gt 1000) {
        $errors.Add("Top cannot exceed 1000 (got: $Top)")
    }

    # Validate MinDuplicateSize
    if ($MinDuplicateSize -lt 0) {
        $errors.Add("MinDuplicateSize cannot be negative (got: $MinDuplicateSize)")
    }

    if ($errors.Count -gt 0) {
        throw "Parameter validation failed:`n$($errors -join "`n")"
    }
}
