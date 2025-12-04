#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    UltraTree disk analysis for NinjaOne
.DESCRIPTION
    Scans all drives for disk usage, duplicates, and cleanup opportunities.
    Results are stored in the TreeSize custom field.
    Critical disk usage triggers an alert via the diskAlert field.
#>

try {
    # Install module if not present, then force import
    if (-not (Get-Module -ListAvailable -Name UltraTree)) {
        Write-Output "Installing UltraTree from PowerShell Gallery..."
        Install-Module -Name UltraTree -Scope AllUsers -Force -AllowClobber
    }
    Import-Module UltraTree -Force -ErrorAction Stop

    # Run the scan
    $results = Get-FolderSizes -AllDrives -FindDuplicates -MaxDepth 5 -Top 50

    # Generate and set the HTML report
    $html = $results | ConvertTo-NinjaOneHtml
    $html | Ninja-Property-Set-Piped treesize

    # Check for critical disk usage (>90%)
    $criticalDrives = $results.DriveInfo | Where-Object { $_.UsedPercent -gt 90 }

    if ($criticalDrives) {
        $driveList = ($criticalDrives | ForEach-Object {
            "$($_.Drive) ($([math]::Round($_.UsedPercent, 1))%)"
        }) -join ', '
        Ninja-Property-Set diskAlert "CRITICAL: $driveList"
    }
    else {
        # Clear alert if no critical drives
        Ninja-Property-Set diskAlert ""
    }

    # Check for warning level (>80%)
    $warningDrives = $results.DriveInfo | Where-Object {
        $_.UsedPercent -gt 80 -and $_.UsedPercent -le 90
    }

    if ($warningDrives -and -not $criticalDrives) {
        $driveList = ($warningDrives | ForEach-Object {
            "$($_.Drive) ($([math]::Round($_.UsedPercent, 1))%)"
        }) -join ', '
        Ninja-Property-Set diskAlert "WARNING: $driveList"
    }

    # Log summary
    Write-Output "UltraTree scan completed successfully"
    Write-Output "Drives scanned: $($results.DriveInfo.Count)"
    Write-Output "Total files: $($results.TotalFiles)"
    Write-Output "Total folders: $($results.TotalFolders)"

    if ($results.TotalDuplicateWasted -gt 0) {
        $wastedGB = [math]::Round($results.TotalDuplicateWasted / 1GB, 2)
        Write-Output "Duplicate waste: ${wastedGB} GB"
    }

    exit 0
}
catch {
    Write-Error "UltraTree scan failed: $_"
    Ninja-Property-Set diskAlert "ERROR: Scan failed - $_"
    exit 1
}