function Get-ThemeIcon {
    <#
    .SYNOPSIS
        Returns icon class from theme by icon name.
    .DESCRIPTION
        Retrieves the FontAwesome icon class for a given icon name from the module theme.
    .PARAMETER IconName
        The name of the icon to retrieve.
    .EXAMPLE
        Get-ThemeIcon -IconName "Folder"
        Returns: "fas fa-folder"
    #>
    param ([string]$IconName)
    $script:Config.Theme.Icons[$IconName]
}
