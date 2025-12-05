#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    UltraTree disk analysis for NinjaOne
.DESCRIPTION
    Scans all drives for disk usage, duplicates, and cleanup opportunities.
    Results are stored in the TreeSize custom field.
#>

try {
    # Install module if not present
    if (-not (Get-Module -ListAvailable -Name UltraTree)) {
        Write-Output "Installing UltraTree from PowerShell Gallery..."
        Install-Module -Name UltraTree -Scope AllUsers -Force -AllowClobber
    }
    Import-Module UltraTree -Force -ErrorAction Stop

    # Run the scan and set custom field
    $results = Get-FolderSizes -AllDrives -FindDuplicates -MaxDepth 5 -Top 50
    $results | ConvertTo-NinjaOneHtml | Ninja-Property-Set-Piped treesize

    # Log summary
    Write-Output "Scan complete: $($results.TotalFiles) files, $($results.TotalFolders) folders"
    if ($results.TotalDuplicateWasted -gt 0) {
        $wastedGB = [math]::Round($results.TotalDuplicateWasted / 1GB, 2)
        Write-Output "Duplicate waste: ${wastedGB} GB"
    }
    exit 0
}
catch {
    Write-Error "UltraTree failed: $_"
    exit 1
}
