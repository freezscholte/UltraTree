function Clear-ErrorLog {
    <#
    .SYNOPSIS
        Clears the scan error log.
    .DESCRIPTION
        Resets the error log collection for a new scan operation.
    #>
    $script:ErrorLog.Clear()
}
