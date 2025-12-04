# NinjaOne Integration

UltraTree is designed for seamless integration with NinjaOne RMM. The HTML output is optimized for WYSIWYG custom fields with responsive design, charts, and color-coded status indicators.

## Overview

The integration allows you to:

- Automatically scan disk usage on all managed devices
- Display beautiful HTML reports in NinjaOne device details
- Set up alerts for critical disk usage
- Schedule scans on a recurring basis

## Prerequisites

- NinjaOne agent installed on target devices
- UltraTree module installed system-wide (see [Installation](installation.md))
- Custom field configured (WYSIWYG/HTML type)

## Step 1: Create the Custom Field

1. Log into NinjaOne
2. Go to **Administration** → **Devices** → **Role Custom Fields**
3. Click **Add** to create a new field
4. Configure the field:
   - **Label**: `TreeSize` (or your preferred display name)
   - **Name**: `treesize` (this is the script reference name)
   - **Type**: **WYSIWYG** (HTML)
   - **Scripts**: Read/Write
5. Click **Save**
6. Assign the field to appropriate device roles

!!! warning "Important"
    The field type **must** be WYSIWYG (HTML). Plain text fields will show raw HTML code instead of the rendered report.

## Step 2: Create the Script

### Basic Script

Minimal script for quick deployment:

```powershell
# UltraTree NinjaOne Script - Install if needed, then run
if (-not (Get-Module -ListAvailable -Name UltraTree)) {
    Install-Module -Name UltraTree -Scope AllUsers -Force -AllowClobber
}
Import-Module UltraTree -Force

$results = Get-FolderSizes -AllDrives -FindDuplicates -MaxDepth 5 -Top 50
$html = $results | ConvertTo-NinjaOneHtml

# Set the custom field (change 'treesize' to match your field name)
$html | Ninja-Property-Set-Piped treesize
```

### Advanced Script with Error Handling

Production-ready script with error handling and disk alerts:

```powershell
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
```

### Lightweight Script (No Duplicates)

Faster scan without duplicate detection:

```powershell
if (-not (Get-Module -ListAvailable -Name UltraTree)) {
    Install-Module -Name UltraTree -Scope AllUsers -Force -AllowClobber
}
Import-Module UltraTree -Force

$results = Get-FolderSizes -AllDrives -MaxDepth 3 -Top 30
$html = $results | ConvertTo-NinjaOneHtml

$html | Ninja-Property-Set-Piped treesize
```

## Step 3: Deploy the Script

1. In NinjaOne, go to **Administration** → **Library** → **Automation**
2. Click **Add** → **New Script**
3. Configure:
   - **Name**: `UltraTree Disk Analysis`
   - **Language**: PowerShell
   - **OS**: Windows
   - **Architecture**: All
4. Paste the script content
5. Save the script

## Step 4: Schedule the Script

1. Go to **Administration** → **Policies**
2. Select the appropriate policy (or create a new one)
3. Navigate to **Scheduled Scripts**
4. Add the UltraTree script with:
   - **Schedule**: Weekly (recommended) or Daily
   - **Run As**: System (required for full disk access)
   - **Time**: Off-peak hours recommended
5. Apply the policy to target devices

!!! tip "Scheduling Recommendations"
    - **Weekly** - Sufficient for most environments
    - **Daily** - For servers or high-activity machines
    - **Monthly** - For stable workstations with little change

## Step 5: Configure Alerts (Optional)

To receive notifications when drives reach critical capacity:

### Create Alert Custom Field

1. Go to **Administration** → **Devices** → **Role Custom Fields**
2. Create a new field:
   - **Label**: `Disk Alert`
   - **Name**: `diskAlert`
   - **Type**: Text
   - **Scripts**: Read/Write

### Create Condition

1. Go to **Administration** → **Library** → **Conditions**
2. Create a new condition:
   - **Name**: `Disk Space Critical`
   - **Type**: Custom Field
   - **Field**: `diskAlert`
   - **Condition**: Contains `CRITICAL`
3. Save the condition

### Create Notification

1. Attach the condition to a notification channel
2. Configure severity and recipients
3. Test with a device that has >90% disk usage

## Viewing Results

1. Navigate to any device running the script
2. Go to the **Details** or **Custom Fields** tab
3. Find the **TreeSize** field
4. The HTML report displays:
   - Summary statistics
   - Per-drive breakdown with charts
   - Top folders by size
   - File type analysis
   - Cleanup suggestions
   - Duplicate files (if enabled)

## Troubleshooting

### Module Not Found

If the script fails with "Module not found":

```powershell
# Verify module is installed system-wide
Get-Module -Name UltraTree -ListAvailable

# If not found, install as Administrator
Install-Module -Name UltraTree -Scope AllUsers
```

### HTML Shows as Raw Code

- Verify the custom field type is **WYSIWYG**, not Text
- Re-create the field if needed

### Scan Taking Too Long

Reduce scope for faster scans:

```powershell
# Reduce depth and disable duplicates
$results = Get-FolderSizes -AllDrives -MaxDepth 3 -Top 25
```

### Access Denied Errors

- Ensure script runs as **System**
- Check that UltraTree is installed in `$env:ProgramFiles\WindowsPowerShell\Modules`

### Empty Report

- Verify the device has fixed NTFS drives
- Check script output for errors
- Run manually on the device to debug

## Example Output

The HTML report in NinjaOne displays:

```
┌─────────────────────────────────────────────┐
│  ULTRATREE DISK ANALYSIS                    │
├─────────────────────────────────────────────┤
│  📊 2 Drives  │  📁 1,234 Items  │  🔍 15   │
│               │                  │  Dupes   │
├─────────────────────────────────────────────┤
│  DRIVE C: - 75% Used (Warning)              │
│  ████████████████░░░░░░  375GB / 500GB      │
│                                             │
│  Top Folders:                               │
│  ▓▓▓▓▓▓▓▓▓▓ Windows      45 GB             │
│  ▓▓▓▓▓▓▓▓   Users        38 GB             │
│  ▓▓▓▓▓▓     Program Files 25 GB            │
│                                             │
│  Cleanup Suggestions:                       │
│  🗑️ Recycle Bin         2.5 GB             │
│  ⏰ Temp Files           1.2 GB             │
│  📦 node_modules         5.8 GB             │
└─────────────────────────────────────────────┘
```

## Best Practices

1. **Start with weekly scans** - Adjust frequency based on needs
2. **Use alerts** - Don't just collect data, act on it
3. **Review cleanup suggestions** - Automate where safe
4. **Monitor duplicates** - Significant space savings possible
5. **Test first** - Run manually before deploying widely
