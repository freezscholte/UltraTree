function Get-ErrorSummary {
    <#
    .SYNOPSIS
        Returns a summary of all logged scan errors.
    .DESCRIPTION
        Aggregates errors by category and returns a formatted summary string.
    #>
    $total = $script:ErrorLog.Count
    if ($total -eq 0) { return $null }

    $byCategory = $script:ErrorLog | Group-Object -Property Category
    $summary = ($byCategory | ForEach-Object {
            "$($_.Count) $($_.Name)"
        }) -join ", "

    return "$total errors: $summary"
}
