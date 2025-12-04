function Get-ThemeColor {
    <#
    .SYNOPSIS
        Returns color from theme by severity name.
    .DESCRIPTION
        Retrieves the hex color code for a given severity level from the module theme.
    .PARAMETER Severity
        The severity level: Danger, Warning, Info, Success, Primary, Muted, Critical, or Free.
    .EXAMPLE
        Get-ThemeColor -Severity "Danger"
        Returns: "#d9534f"
    #>
    param (
        [ValidateSet("Danger", "Warning", "Info", "Success", "Primary", "Muted", "Critical", "Free")]
        [string]$Severity
    )
    $script:Config.Theme.Colors[$Severity]
}
