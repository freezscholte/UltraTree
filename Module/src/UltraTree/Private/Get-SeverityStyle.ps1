function Get-SeverityStyle {
    <#
    .SYNOPSIS
        Returns hashtable with Color, Icon, and Class for a severity level.
    .DESCRIPTION
        Combines color, icon, and CSS class information for a given severity.
    .PARAMETER Severity
        The severity level: Danger, Warning, Info, or Success.
    .EXAMPLE
        Get-SeverityStyle -Severity "Warning"
        Returns: @{ Color = "#f0ad4e"; Icon = "fa-solid fa-triangle-exclamation"; Class = "warning" }
    #>
    param (
        [ValidateSet("Danger", "Warning", "Info", "Success")]
        [string]$Severity
    )
    @{
        Color = Get-ThemeColor -Severity $Severity
        Icon  = Get-ThemeIcon -IconName $Severity
        Class = $Severity.ToLower()
    }
}
