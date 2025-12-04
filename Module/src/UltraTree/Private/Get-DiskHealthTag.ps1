function Get-DiskHealthTag {
    <#
    .SYNOPSIS
        Returns health status based on disk usage percent.
    .DESCRIPTION
        Determines disk health status (Critical, Warning, or Healthy) based on usage percentage.
    .PARAMETER UsedPercent
        The percentage of disk space used.
    .EXAMPLE
        Get-DiskHealthTag -UsedPercent 95
        Returns: @{ Class = "expired"; Text = "Critical" }
    #>
    param ([double]$UsedPercent)

    $cfg = $script:Config.DiskHealth
    if ($UsedPercent -gt $cfg.CriticalPercent) {
        return @{ Class = "expired"; Text = "Critical" }
    }
    elseif ($UsedPercent -gt $cfg.WarningPercent) {
        return @{ Class = "disabled"; Text = "Warning" }
    }
    else {
        return @{ Class = ""; Text = "Healthy" }
    }
}
