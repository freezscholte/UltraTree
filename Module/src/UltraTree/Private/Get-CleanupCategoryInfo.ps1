function Get-CleanupCategoryInfo {
    <#
    .SYNOPSIS
        Returns cleanup category info by name.
    .DESCRIPTION
        Retrieves icon and color information for a cleanup category.
    .PARAMETER CategoryName
        The name of the cleanup category.
    .EXAMPLE
        Get-CleanupCategoryInfo -CategoryName "recycleBin"
        Returns: @{ Icon = "fas fa-trash"; Color = "#f0ad4e" }
    #>
    param ([string]$CategoryName)

    $category = $script:CleanupCategories | Where-Object { $_.Name -eq $CategoryName }
    if ($category) {
        return @{
            Icon  = Get-ThemeIcon -IconName $category.Icon
            Color = Get-ThemeColor -Severity $category.Severity
        }
    }
    # Default fallback
    return @{
        Icon  = Get-ThemeIcon -IconName "Folder"
        Color = Get-ThemeColor -Severity "Info"
    }
}
