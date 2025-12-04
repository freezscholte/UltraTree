# UltraTree

### Lightning-Fast Disk Space Analysis for Windows

A powerful PowerShell disk scanner that goes beyond traditional tree-size tools:

**Key Features:**
- Ultra-fast scanning using USN Journal / MFT enumeration
- Smart 3-stage duplicate detection (Size → xxHash64 → Full Compare)
- Intelligent cleanup suggestions (temp files, logs, cache, old installers)
- Beautiful HTML reports with interactive charts
- Dynamic memory management for handling massive filesystems
- Top folders, file types, and wasted space analysis
- Configurable thresholds and display limits

Built for system administrators, MSPs, and power users who need to understand where disk space is going—fast.

---

## Installation

### From PowerShell Gallery

```powershell
Install-Module -Name UltraTree -Scope CurrentUser
```

### Manual Installation

```powershell
# Run as Administrator - installs system-wide (required for NinjaOne/SYSTEM account)
git clone https://github.com/freezscholte/UltraTree.git "$env:TEMP\UltraTree"
Copy-Item -Path "$env:TEMP\UltraTree\Module\src\UltraTree" -Destination "$env:ProgramFiles\WindowsPowerShell\Modules\UltraTree" -Recurse -Force
Remove-Item -Path "$env:TEMP\UltraTree" -Recurse -Force

Import-Module UltraTree -Force
```

---

## Quick Start

```powershell
# Scan C: drive
$results = Get-FolderSizes -DriveLetter C

# Scan all drives with duplicate detection
$results = Get-FolderSizes -AllDrives -FindDuplicates -MaxDepth 5 -Top 50

# Generate HTML report
$html = $results | ConvertTo-NinjaOneHtml

# Save to file
$html | Out-File "DiskReport.html" -Encoding UTF8
```

---

## NinjaOne Integration

UltraTree is designed for NinjaOne RMM. Set the HTML report directly to a WYSIWYG custom field:

```powershell
$results = Get-FolderSizes -AllDrives -FindDuplicates
$html = $results | ConvertTo-NinjaOneHtml
$html | Ninja-Property-Set-Piped treesize
```

---

## Documentation

**[Full Documentation](Module/README.md)** - Complete reference including:
- All parameters and options
- Return object structure
- NinjaOne setup guide (custom fields, scripts, scheduling, alerts)
- Configuration reference
- Troubleshooting

---

## Requirements

- PowerShell 5.1+
- Windows (NTFS drives)
- Administrator privileges for full access

---

## Author

Jan Scholte

## License

MIT License
