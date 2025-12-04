function Get-DiskUsedColor {
    <#
    .SYNOPSIS
        Returns appropriate color for disk usage based on percent.
    .DESCRIPTION
        Selects color (Critical, Warning, or Success) based on disk usage percentage.
    .PARAMETER UsedPercent
        The percentage of disk space used.
    .EXAMPLE
        Get-DiskUsedColor -UsedPercent 95
        Returns: "#FF6B6B"
    #>
    param ([double]$UsedPercent)

    $cfg = $script:Config.DiskHealth
    if ($UsedPercent -gt $cfg.CriticalPercent) {
        return Get-ThemeColor -Severity "Critical"
    }
    elseif ($UsedPercent -gt $cfg.WarningPercent) {
        return Get-ThemeColor -Severity "Warning"
    }
    else {
        return Get-ThemeColor -Severity "Success"
    }
}
