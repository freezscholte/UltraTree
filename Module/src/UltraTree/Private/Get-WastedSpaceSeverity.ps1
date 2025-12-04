function Get-WastedSpaceSeverity {
    <#
    .SYNOPSIS
        Returns severity level based on wasted space amount.
    .DESCRIPTION
        Categorizes wasted space as Danger, Warning, or Info based on thresholds.
    .PARAMETER WastedBytes
        The amount of wasted space in bytes.
    .EXAMPLE
        Get-WastedSpaceSeverity -WastedBytes 600MB
        Returns: "Danger"
    #>
    param ([long]$WastedBytes)

    $cfg = $script:Config.Thresholds
    if ($WastedBytes -gt $cfg.DangerWasted) { return "Danger" }
    elseif ($WastedBytes -gt $cfg.WarningWasted) { return "Warning" }
    else { return "Info" }
}
