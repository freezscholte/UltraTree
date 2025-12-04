# UltraTree

Lightning-fast disk space analyzer for Windows using MFT/USN Journal enumeration.

## Synopsis

UltraTree is a PowerShell module that provides ultra-fast disk space analysis by directly reading the NTFS Master File Table (MFT). It's designed for system administrators and MSPs who need quick insights into disk usage, duplicate files, and cleanup opportunities—with beautiful HTML reports optimized for NinjaOne RMM.

**Why UltraTree over TreeSize, WinDirStat, or built-in tools?**

- **10-100x faster** - MFT enumeration vs. recursive directory walking
- **Duplicate detection** - 3-stage detection (Size → xxHash64 → Full Compare)
- **RMM-ready output** - HTML reports designed for NinjaOne custom fields
- **Zero dependencies** - Pure PowerShell with embedded C# for performance
- **Automated cleanup insights** - Identifies temp files, caches, node_modules, etc.

## Features

- Ultra-fast NTFS scanning using MFT enumeration
- Smart 3-stage duplicate file detection using xxHash64
- Intelligent cleanup suggestions (temp files, logs, cache, old installers)
- Beautiful HTML reports with interactive charts
- Multi-drive scanning with exclusion support
- Dynamic memory management for massive filesystems
- Configurable thresholds and display limits

## Installation

### From PowerShell Gallery

```powershell
Install-Module -Name UltraTree -Scope CurrentUser
```

### Manual Installation (System-Wide)

Install to the system-wide modules folder so it's available to all users and the SYSTEM account (required for NinjaOne):

```powershell
# Run as Administrator
git clone https://github.com/freezscholte/UltraTree.git "$env:TEMP\UltraTree"
Copy-Item -Path "$env:TEMP\UltraTree\Module\src\UltraTree" -Destination "$env:ProgramFiles\WindowsPowerShell\Modules\UltraTree" -Recurse -Force
Remove-Item -Path "$env:TEMP\UltraTree" -Recurse -Force

# Verify installation
Import-Module UltraTree -Force
Get-Command -Module UltraTree
```

### Manual Installation (Current User Only)

```powershell
git clone https://github.com/freezscholte/UltraTree.git "$env:TEMP\UltraTree"
Copy-Item -Path "$env:TEMP\UltraTree\Module\src\UltraTree" -Destination "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\UltraTree" -Recurse -Force
Remove-Item -Path "$env:TEMP\UltraTree" -Recurse -Force
```

### Development / Direct Import

```powershell
# For development or one-time use, import directly without installing
git clone https://github.com/freezscholte/UltraTree.git
Import-Module ./UltraTree/Module/src/UltraTree -Force
```

## Quick Start

```powershell
# Scan C: drive
$results = Get-FolderSizes -DriveLetter C

# Scan all drives with duplicate detection
$results = Get-FolderSizes -AllDrives -FindDuplicates

# Generate HTML report
$html = $results | ConvertTo-NinjaOneHtml

# Save to file
$html | Out-File -FilePath "C:\Reports\DiskReport.html" -Encoding UTF8
```

---

## Function Reference

### Get-FolderSizes

Scans one or more drives and returns detailed disk usage information.

#### Syntax

```powershell
Get-FolderSizes [-DriveLetter] <String> [-MaxDepth <Int32>] [-Top <Int32>]
    [-FolderSize] [-FileSize] [-VerboseOutput] [-FindDuplicates] [-MinDuplicateSize <Int64>]

Get-FolderSizes -AllDrives [-ExcludeDrives <String[]>] [-MaxDepth <Int32>] [-Top <Int32>]
    [-FolderSize] [-FileSize] [-VerboseOutput] [-FindDuplicates] [-MinDuplicateSize <Int64>]
```

#### Parameters

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| **DriveLetter** | String | - | - | Drive letter to scan (e.g., "C"). Required unless `-AllDrives` is specified. |
| **AllDrives** | Switch | `$false` | - | Scan all fixed drives on the system. |
| **ExcludeDrives** | String[] | - | - | Array of drive letters to skip when using `-AllDrives`. |
| **MaxDepth** | Int32 | `5` | 1-20 | Maximum folder depth to include in results. |
| **Top** | Int32 | `40` | 1-1000 | Maximum number of items to return per drive. |
| **FolderSize** | Switch | `$false` | - | Show only folders in results (excludes files). |
| **FileSize** | Switch | `$false` | - | Show only large files in results (excludes folders). |
| **FindDuplicates** | Switch | `$false` | - | Enable duplicate file detection using xxHash64. |
| **MinDuplicateSize** | Int64 | `10MB` | 0+ | Minimum file size to consider for duplicate detection. |
| **VerboseOutput** | Switch | `$false` | - | Display progress information during scan. |

#### Examples

**Scan a single drive:**
```powershell
$results = Get-FolderSizes -DriveLetter C -MaxDepth 5 -Top 50
```

**Scan all drives except D:**
```powershell
$results = Get-FolderSizes -AllDrives -ExcludeDrives @("D") -MaxDepth 3
```

**Find duplicates larger than 50MB:**
```powershell
$results = Get-FolderSizes -DriveLetter C -FindDuplicates -MinDuplicateSize 50MB
```

**Show only large files:**
```powershell
$results = Get-FolderSizes -DriveLetter C -FileSize -Top 100
```

**Verbose output for monitoring:**
```powershell
$results = Get-FolderSizes -AllDrives -FindDuplicates -VerboseOutput
```

---

### ConvertTo-NinjaOneHtml

Converts scan results into an HTML report optimized for NinjaOne WYSIWYG custom fields.

#### Syntax

```powershell
ConvertTo-NinjaOneHtml [-ScanResults] <PSCustomObject>
```

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| **ScanResults** | PSCustomObject | Yes | Output from `Get-FolderSizes`. Supports pipeline input. |

#### Examples

**Basic usage:**
```powershell
$results = Get-FolderSizes -DriveLetter C
$html = ConvertTo-NinjaOneHtml -ScanResults $results
```

**Pipeline usage:**
```powershell
$html = Get-FolderSizes -AllDrives | ConvertTo-NinjaOneHtml
```

**Save to file:**
```powershell
Get-FolderSizes -AllDrives -FindDuplicates |
    ConvertTo-NinjaOneHtml |
    Out-File "DiskReport.html" -Encoding UTF8
```

---

## Return Object Structure

`Get-FolderSizes` returns a `PSCustomObject` with the following properties:

| Property | Type | Description |
|----------|------|-------------|
| **Items** | List | Folders/files sorted by size descending |
| **FileTypes** | List | File extension statistics |
| **CleanupSuggestions** | List | Identified cleanup opportunities |
| **Duplicates** | List | Duplicate file groups (if `-FindDuplicates` specified) |
| **DriveInfo** | List | Drive capacity and usage for each scanned drive |
| **TotalDuplicateWasted** | Int64 | Total bytes wasted by duplicate files |
| **TotalFiles** | Int64 | Total files scanned |
| **TotalFolders** | Int64 | Total folders scanned |
| **TotalErrorCount** | Int64 | Count of access errors encountered |

### Items Structure

```powershell
[PSCustomObject]@{
    Drive        = "C:"           # Drive letter
    Path         = "C:\Users"     # Full path
    Size         = "15.20 GB"     # Human-readable size
    SizeBytes    = 16324567890    # Size in bytes
    IsDirectory  = $true          # True for folders
    LastModified = "2024-01-15"   # Last modified date
}
```

### DriveInfo Structure

```powershell
[PSCustomObject]@{
    Drive       = "C:"            # Drive letter
    TotalSize   = 500107862016    # Total capacity in bytes
    UsedSpace   = 350075703296    # Used space in bytes
    FreeSpace   = 150032158720    # Free space in bytes
    UsedPercent = 70.0            # Usage percentage
}
```

### Duplicates Structure

```powershell
[PSCustomObject]@{
    Drive       = "C:"                              # Drive letter
    Hash        = "a1b2c3d4e5f6..."                 # xxHash64 hash
    FileSize    = 104857600                         # Size of each file
    Files       = @("C:\path1\file.exe", "C:\path2\file.exe")  # Duplicate paths
    WastedSpace = 104857600                         # Wasted bytes
}
```

---

## NinjaOne Integration

UltraTree is designed for seamless integration with NinjaOne RMM. The HTML output is optimized for WYSIWYG custom fields with responsive design, charts, and color-coded status indicators.

### Prerequisites

- NinjaOne agent installed on target devices
- Custom field configured (WYSIWYG/HTML type)
- Script deployed via NinjaOne automation

### Step 1: Create the Custom Field

1. Log into NinjaOne
2. Go to **Administration** → **Devices** → **Role Custom Fields**
3. Click **Add** to create a new field
4. Configure the field:
   - **Label**: `TreeSize` (or your preferred name)
   - **Name**: `treesize` (this is used in scripts)
   - **Type**: **WYSIWYG** (HTML)
   - **Scripts**: Read/Write
5. Click **Save**
6. Assign the field to appropriate device roles

### Step 2: Create the Script

#### Basic Script

```powershell
# UltraTree NinjaOne Script
# Scans all drives and sets the TreeSize custom field

Import-Module UltraTree -Force

$results = Get-FolderSizes -AllDrives -FindDuplicates -MaxDepth 5 -Top 50
$html = $results | ConvertTo-NinjaOneHtml

# Set the custom field (change 'treesize' to match your field name)
$html | Ninja-Property-Set-Piped treesize
```

#### Advanced Script with Error Handling and Alerts

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
    # Import the module
    Import-Module UltraTree -ErrorAction Stop

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

    # Check for significant duplicate waste (>1GB)
    if ($results.TotalDuplicateWasted -gt 1GB) {
        $wastedGB = [math]::Round($results.TotalDuplicateWasted / 1GB, 2)
        Write-Output "Warning: ${wastedGB}GB wasted on duplicate files"
    }

    Write-Output "UltraTree scan completed successfully"
    Write-Output "Total files scanned: $($results.TotalFiles)"
    Write-Output "Total folders scanned: $($results.TotalFolders)"
    exit 0
}
catch {
    Write-Error "UltraTree scan failed: $_"
    exit 1
}
```

### Step 3: Deploy the Script

1. In NinjaOne, go to **Administration** → **Library** → **Automation**
2. Click **Add** → **New Script**
3. Configure:
   - **Name**: `UltraTree Disk Analysis`
   - **Language**: PowerShell
   - **OS**: Windows
   - **Architecture**: All
4. Paste the script content
5. Save the script

### Step 4: Schedule the Script

1. Go to **Administration** → **Policies**
2. Select the appropriate policy (or create a new one)
3. Navigate to **Scheduled Scripts**
4. Add the UltraTree script with:
   - **Schedule**: Weekly (recommended) or Daily
   - **Run As**: System (required for full disk access)
5. Apply the policy to target devices

### Step 5: Configure Alerts (Optional)

To receive notifications when drives reach critical capacity:

1. Go to **Administration** → **Library** → **Conditions**
2. Create a new condition:
   - **Name**: `Disk Space Critical`
   - **Type**: Custom Field
   - **Field**: `diskAlert`
   - **Condition**: Contains "CRITICAL"
3. Attach the condition to a notification channel

### Viewing Results

1. Navigate to any device running the script
2. Go to the **Details** or **Custom Fields** tab
3. Find the **TreeSize** field
4. The HTML report displays:
   - Summary statistics (drives, items, duplicates, cleanup potential)
   - Per-drive breakdown with usage charts
   - Top folders by size
   - File type analysis
   - Cleanup suggestions
   - Duplicate files (if enabled)

---

## Configuration Reference

UltraTree uses internal configuration that can be customized by modifying `Private/Configuration.ps1`.

### Thresholds

| Setting | Default | Description |
|---------|---------|-------------|
| `CleanupMin` | 100MB | Minimum size for cleanup suggestions |
| `DuplicateMin` | 10MB | Minimum file size for duplicate detection |
| `LargeFile` | 100MB | Files above this size shown in results |
| `DangerWasted` | 500MB | Wasted space marked as "Danger" |
| `WarningWasted` | 100MB | Wasted space marked as "Warning" |
| `ErrorWarning` | 50 | Show warning if >N files couldn't be read |

### Display Limits

| Setting | Default | Description |
|---------|---------|-------------|
| `MaxDuplicateGroups` | 20 | Max duplicate groups in HTML report |
| `MaxPathsPerGroup` | 5 | Max file paths shown per duplicate group |
| `MaxTopFolders` | 8 | Top folders displayed in bar chart |
| `MaxFileTypes` | 10 | Top file types to display |
| `MaxResults` | 40 | Max items in results table |
| `MaxPathLength` | 50 | Truncate paths longer than this |

### Disk Health Thresholds

| Setting | Default | Description |
|---------|---------|-------------|
| `CriticalPercent` | 90 | Usage % marked as Critical |
| `WarningPercent` | 75 | Usage % marked as Warning |

---

## Cleanup Categories

UltraTree automatically identifies cleanup opportunities in these categories:

| Category | Detected Patterns | Description |
|----------|-------------------|-------------|
| **Recycle Bin** | `$Recycle.Bin`, `RECYCLER` | Recycle bin contents that can be emptied |
| **Temp Files** | `\Temp\`, `\tmp\`, `AppData\Local\Temp` | Temporary files safe to delete |
| **Cache Files** | `\Cache\`, `.cache\`, `CachedData` | Application cache files |
| **node_modules** | `\node_modules\` | Node.js dependencies (run `npm install` to restore) |
| **Git Data** | `\.git\` | Git repository data |
| **Downloads** | `\Downloads\` | Review and clean old downloads |
| **Windows Installer** | `\Windows\Installer\` | Windows Installer cache (use Disk Cleanup) |

---

## Troubleshooting

### "Access Denied" Errors

UltraTree requires administrator privileges to scan all folders. Run PowerShell as Administrator or ensure NinjaOne scripts run as SYSTEM.

```powershell
# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Run as Administrator for full disk access"
}
```

### Scan Taking Too Long

For very large drives, reduce the scope:

```powershell
# Reduce depth and results
$results = Get-FolderSizes -DriveLetter C -MaxDepth 3 -Top 25

# Skip duplicate detection (most time-consuming)
$results = Get-FolderSizes -AllDrives -MaxDepth 5  # No -FindDuplicates
```

### High Memory Usage

UltraTree includes dynamic memory management, but for drives with millions of files:

```powershell
# Scan one drive at a time
$drives = @("C", "D", "E")
$results = foreach ($drive in $drives) {
    Get-FolderSizes -DriveLetter $drive -MaxDepth 3
    [GC]::Collect()  # Force garbage collection between drives
}
```

### HTML Not Rendering in NinjaOne

Ensure the custom field is configured as **WYSIWYG** type, not plain text. The HTML includes external dependencies (Bootstrap, Charts.css) that require internet connectivity for full rendering.

---

## Requirements

- **PowerShell**: 5.1 or later
- **Operating System**: Windows (NTFS drives only)
- **Permissions**: Administrator for full access
- **.NET Framework**: 4.5+ (included with Windows 10/11)

---

## Development

### Local Documentation Server

To preview the documentation locally:

```bash
# Install MkDocs (once)
pip install mkdocs

# Start local server from Module folder
cd Module
python -m mkdocs serve
```

Open http://127.0.0.1:8000/ in your browser. Changes to docs files auto-reload.

### Running Tests

```powershell
cd Module/src
Invoke-Build -Task Test
```

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](.github/CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

Jan Scholte

---

## Version

Current version: **1.0.0**
