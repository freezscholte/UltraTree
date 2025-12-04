function Get-SizeCategory {
    <#
    .SYNOPSIS
        Returns CSS class based on size thresholds.
    .DESCRIPTION
        Categorizes a size value into danger, warning, other, unknown, or success.
    .PARAMETER SizeBytes
        The size in bytes to categorize.
    .EXAMPLE
        Get-SizeCategory -SizeBytes 150GB
        Returns: "danger"
    #>
    param ([long]$SizeBytes)

    $cfg = $script:Config.SizeCategories
    switch ($SizeBytes) {
        { $_ -gt $cfg.Danger }  { return "danger" }
        { $_ -gt $cfg.Warning } { return "warning" }
        { $_ -gt $cfg.Other }   { return "other" }
        { $_ -gt $cfg.Unknown } { return "unknown" }
        default                 { return "success" }
    }
}
