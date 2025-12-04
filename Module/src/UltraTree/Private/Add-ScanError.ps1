function Add-ScanError {
    <#
    .SYNOPSIS
        Adds an error entry to the scan error log.
    .DESCRIPTION
        Records scan errors with categorization for later analysis.
    .PARAMETER Path
        The file or folder path that caused the error.
    .PARAMETER Category
        The error category: access, io, timeout, or unknown.
    .PARAMETER Message
        Optional error message details.
    #>
    param (
        [string]$Path,
        [ValidateSet("access", "io", "timeout", "unknown")]
        [string]$Category = "unknown",
        [string]$Message = ""
    )
    $script:ErrorLog.Add([PSCustomObject]@{
            Timestamp = Get-Date
            Path      = $Path
            Category  = $Category
            Message   = $Message
        })
}
