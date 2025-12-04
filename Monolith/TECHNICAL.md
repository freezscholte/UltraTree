# UltraTree

Ultra-fast disk space analyzer using MFT (Master File Table) / USN Journal enumeration for Windows systems. Designed for NinjaOne RMM deployment with beautiful HTML reporting.

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Parameters](#parameters)
- [Configuration](#configuration)
- [Output](#output)
- [HTML Report Sections](#html-report-sections)
- [Cleanup Categories](#cleanup-categories)
  - [Adding Custom Cleanup Categories](#adding-custom-cleanup-categories)
- [Testing](#testing)
- [NinjaOne Integration](#ninjaone-integration)
- [Troubleshooting](#troubleshooting)
- [Technical Deep Dive](#technical-deep-dive)
  - [MFT Enumeration](#mft-master-file-table-enumeration)
  - [Duplicate Detection with xxHash64](#duplicate-detection-with-xxhash64)
  - [Smart Memory Management](#smart-memory-management)
  - [Performance Characteristics](#performance-characteristics)

---

## Features

- **Ultra-Fast Scanning**: Uses MFT enumeration instead of traditional file system traversal - scans entire drives in seconds
- **Multi-Drive Support**: Scan single drive or all fixed drives simultaneously
- **Duplicate File Detection**: Identifies duplicate files using progressive content comparison (size > partial hash > full hash)
- **Cleanup Suggestions**: Automatically detects common space-wasting folders (Recycle Bin, Temp, Cache, node_modules, etc.)
- **File Type Analysis**: Shows space usage by file extension
- **Disk Health Monitoring**: Visual indicators for disk space usage levels
- **Beautiful HTML Reports**: Bootstrap-styled responsive reports with charts
- **NinjaOne Ready**: Outputs HTML fragments compatible with NinjaOne WYSIWYG custom fields
- **Configurable Thresholds**: All limits and thresholds centralized in configuration
- **Pester Test Suite**: Comprehensive unit tests included

---

## Requirements

- **Operating System**: Windows 10/11 or Windows Server 2016+
- **PowerShell**: Version 5.1 or later
- **Permissions**: Administrator privileges required (MFT access)
- **Disk Type**: NTFS formatted drives only

---

## Installation

1. Download `CF-UltraTreesizeNinja-V9.ps1` to your desired location
2. (Optional) Download `CF-UltraTreesizeNinja-V9.Tests.ps1` for running tests

```powershell
# No installation required - just run the script
.\CF-UltraTreesizeNinja-V9.ps1
```

---

## Quick Start

### Scan All Drives (Default)
```powershell
.\CF-UltraTreesizeNinja-V9.ps1
```

### Use as Module (Custom Scans)
```powershell
# Load functions without executing main scan
. .\CF-UltraTreesizeNinja-V9.ps1 -TestMode

# Scan specific drive
$results = Get-FolderSizes -DriveLetter "C" -MaxDepth 5 -Top 50

# Scan all drives with duplicate detection
$results = Get-FolderSizes -AllDrives -FindDuplicates -VerboseOutput

# Generate HTML report
$html = ConvertTo-NinjaOneHtml -ScanResults $results
```

---

## Parameters

### Script Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `-TestMode` | Switch | Loads functions without executing main scan. Used for testing and module usage. |

### Get-FolderSizes Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-DriveLetter` | String | - | Single drive letter to scan (e.g., "C"). Required if `-AllDrives` not specified. |
| `-AllDrives` | Switch | - | Scan all fixed drives. Required if `-DriveLetter` not specified. |
| `-MaxDepth` | Int | 5 | Maximum folder depth to scan (1-20). |
| `-Top` | Int | 40 | Number of top results to return (1-1000). |
| `-FolderSize` | Switch | - | Include folders in results. |
| `-FileSize` | Switch | - | Include individual files in results. |
| `-VerboseOutput` | Switch | - | Show progress and timing information during scan. |
| `-FindDuplicates` | Switch | - | Enable duplicate file detection. |
| `-MinDuplicateSize` | Long | 10MB | Minimum file size for duplicate detection. |
| `-ExcludeDrive` | String[] | - | Drive letter(s) to exclude when using `-AllDrives`. Works with or without colon (e.g., "D" or "D:"). |

### Usage Examples

```powershell
# Load as module
. .\CF-UltraTreesizeNinja-V9.ps1 -TestMode

# Basic scan of C: drive
$results = Get-FolderSizes -DriveLetter "C" -MaxDepth 5 -Top 40

# Deep scan with files
$results = Get-FolderSizes -DriveLetter "D" -MaxDepth 10 -Top 100 -FolderSize -FileSize

# All drives with duplicates and verbose output
$results = Get-FolderSizes -AllDrives -FindDuplicates -MinDuplicateSize 50MB -VerboseOutput

# Quick top-level scan
$results = Get-FolderSizes -AllDrives -MaxDepth 2 -Top 20

# Exclude single drive
Get-FolderSizes -AllDrives -ExcludeDrive D

# Exclude multiple drives
Get-FolderSizes -AllDrives -ExcludeDrive D,E

# Works with or without colon
Get-FolderSizes -AllDrives -ExcludeDrive "D:", "E:"
```

---

## Configuration

All thresholds and settings are centralized in the `$script:Config` object at the top of the script. Modify these values to customize behavior.

### Size Thresholds

```powershell
$script:Config.Thresholds = @{
    CleanupMin      = 100MB     # Minimum size for cleanup suggestions
    DuplicateMin    = 10MB      # Minimum file size for duplicate detection
    LargeFile       = 100MB     # Files above this shown in results
    DangerWasted    = 500MB     # "Danger" severity threshold
    WarningWasted   = 100MB     # "Warning" severity threshold
    ErrorWarning    = 50        # Show warning if more than X errors
}
```

### Display Limits

```powershell
$script:Config.Display = @{
    MaxDuplicateGroups = 20     # Max duplicate groups to display
    MaxPathsPerGroup   = 5      # Max paths shown per duplicate group
    MaxTopFolders      = 8      # Top folders in bar chart
    MaxFileTypes       = 10     # Top file types to show
    MaxResults         = 40     # Max items in results table
    MaxPathLength      = 50     # Truncate paths longer than this
    MaxLabelLength     = 12     # Truncate chart labels longer than this
}
```

### Disk Health Thresholds

```powershell
$script:Config.DiskHealth = @{
    CriticalPercent = 90        # Red/Critical above this
    WarningPercent  = 75        # Yellow/Warning above this
}
```

### Size Categories (Row Styling)

```powershell
$script:Config.SizeCategories = @{
    Danger  = 100GB             # Red highlight
    Warning = 50GB              # Yellow highlight
    Other   = 10GB              # Light highlight
    Unknown = 1GB               # Minimal highlight
}
```

### Theme Colors

```powershell
$script:Config.Theme.Colors = @{
    Danger   = "#d9534f"        # Red
    Warning  = "#f0ad4e"        # Orange/Yellow
    Info     = "#5bc0de"        # Blue
    Success  = "#4ECDC4"        # Teal/Green
    Primary  = "#337ab7"        # Primary Blue
    Muted    = "#999999"        # Gray
    Critical = "#FF6B6B"        # Bright Red
    Free     = "#95a5a6"        # Light Gray
}
```

---

## Output

### Console Output (Verbose Mode)
```
Processing drive C:
  MFT scan completed in 1.23s - 485,234 files, 52,341 folders
  Stage 1 (size filter): 12,456 files in 3,421 groups
  Stage 2 (quick hash): 500 files in 150 groups, 0 errors | 0.45s
  Stage 3 (full hash): 45 groups, 234 comparisons | 1.20s
  Duplicate scan total: 1.75s
HTML output saved to treesize-v9-output.html
```

### File Output

| File | Description |
|------|-------------|
| `treesize-v9-output.html` | Full HTML report with CSS/JS (for local viewing) |
| NinjaOne Custom Field | HTML fragment (NinjaOne provides CSS/JS) |

---

## HTML Report Sections

The generated HTML report includes the following sections:

### 1. Summary Statistics
- Total files and folders scanned
- Total used/free space across all drives
- Error count (if any)

### 2. Drive Overview Cards
Per-drive information including:
- Total/Used/Free space
- Usage percentage with progress bar
- Health status tag (Healthy/Warning/Critical)

### 3. Cleanup Suggestions
Actionable recommendations for reclaiming space:
- Recycle Bin contents
- Temporary files
- Cache folders
- node_modules directories
- Git repository data
- Downloads folder
- Windows Installer cache

### 4. Top Folders Bar Chart
Visual chart showing the largest folders on each drive.

### 5. File Types Table
Breakdown of space usage by file extension:
- Extension name
- Total size
- File count

### 6. Duplicate Files Table
Groups of identical files with:
- File size
- Wasted space (duplicates beyond first)
- File paths (truncated for display)

### 7. Full Results Table
Complete list of largest items:
- Path
- Size
- Type (folder/file icon)
- Last modified date

---

## Cleanup Categories

The script automatically detects these space-wasting categories:

| Category | Patterns | Severity | Description |
|----------|----------|----------|-------------|
| Recycle Bin | `$Recycle.Bin`, `RECYCLER` | Warning | Empty recycle bin to reclaim space |
| Temp Files | `\Temp\`, `\tmp\`, `AppData\Local\Temp` | Info | Temporary files safe to delete |
| Cache Files | `\Cache\`, `.cache\`, `CachedData` | Info | Application cache files |
| node_modules | `\node_modules\` | Info | Node.js dependencies (restore with npm install) |
| .git Folders | `\.git\` | Info | Git repository data |
| Downloads | `\Downloads\` | Warning | Review and clean old downloads |
| Windows Installer | `\Windows\Installer\` | Danger | Use Disk Cleanup tool |

### Adding Custom Cleanup Categories

You can easily add your own cleanup categories by editing the `$script:CleanupCategories` array near the top of the script (around line 114).

#### Category Structure

Each category is a hashtable with these properties:

| Property | Type | Description |
|----------|------|-------------|
| `Name` | String | Unique identifier (no spaces, used internally) |
| `DisplayName` | String | Human-readable name shown in reports |
| `Patterns` | String[] | Array of path patterns to match (case-insensitive) |
| `Icon` | String | Font Awesome icon name (without `fa-` prefix) |
| `Severity` | String | `Info`, `Warning`, or `Danger` (affects styling) |
| `Description` | String | Explanation shown in cleanup suggestions |

#### Example: Adding a Custom Category

```powershell
# Add to the $script:CleanupCategories array:
@{
    Name        = "dockerData"
    DisplayName = "Docker Data"
    Patterns    = @('\Docker\', '\docker\volumes\', '\.docker\')
    Icon        = "Server"
    Severity    = "Warning"
    Description = "Docker images and volumes - prune unused with 'docker system prune'"
}
```

#### More Examples

```powershell
# Python virtual environments
@{
    Name        = "pythonVenv"
    DisplayName = "Python venv"
    Patterns    = @('\venv\', '\.venv\', '\virtualenv\')
    Icon        = "Code"
    Severity    = "Info"
    Description = "Python virtual environments - recreate with 'python -m venv'"
}

# Browser profiles
@{
    Name        = "browserData"
    DisplayName = "Browser Data"
    Patterns    = @('\Google\Chrome\User Data\', '\Mozilla\Firefox\Profiles\', '\Microsoft\Edge\User Data\')
    Icon        = "Globe"
    Severity    = "Warning"
    Description = "Browser cache and data - clear from browser settings"
}

# IDE/Editor caches
@{
    Name        = "ideCache"
    DisplayName = "IDE Cache"
    Patterns    = @('\.vscode\', '\.idea\', '\JetBrains\')
    Icon        = "Laptop"
    Severity    = "Info"
    Description = "IDE workspace and cache files"
}
```

#### Available Icons

Common Font Awesome icons you can use:
- `Trash`, `Clock`, `Database`, `Code`, `CodeBranch`
- `Download`, `Cog`, `Server`, `Globe`, `Laptop`
- `File`, `Folder`, `Archive`, `Cloud`, `HardDrive`

#### Pattern Matching Tips

- Patterns are matched against the **full file path**
- Use backslashes: `\FolderName\` (not forward slashes)
- Patterns are **case-insensitive**
- Include trailing backslash to match folders: `\node_modules\`
- Multiple patterns per category are OR-matched (any pattern triggers the category)

---

## Testing

The script includes a comprehensive Pester test suite.

### Running Tests

```powershell
# Install Pester (if needed)
Install-Module -Name Pester -Force -SkipPublisherCheck

# Run tests (Pester 5.x)
Invoke-Pester -Path .\CF-UltraTreesizeNinja-V9.Tests.ps1 -Output Detailed

# Run tests (Pester 4.x)
Invoke-Pester -Path .\CF-UltraTreesizeNinja-V9.Tests.ps1
```

### Test Coverage

- Configuration structure validation
- Format-ByteSize function (all size ranges)
- Theme functions (colors, icons, severity styles)
- Size category classification
- Disk health tagging
- Input validation
- HTML generation functions
- Error tracking system

---

## NinjaOne Integration

### Setup

1. Create a WYSIWYG custom field in NinjaOne (e.g., `treesize`)
2. Deploy the script via NinjaOne automation
3. The script automatically outputs to the custom field

### Custom Field Configuration

```powershell
# In the main execution section, change the field name:
$html | Ninja-Property-Set-Piped yourfieldname
```

### Scheduling

Recommended schedule: Daily or Weekly depending on environment size.

### Output Considerations

- NinjaOne WYSIWYG fields already include Bootstrap, Font Awesome, and Charts.css
- The script outputs HTML fragments (not full documents) for NinjaOne
- Local file output includes full HTML wrapper with all dependencies

---

## Troubleshooting

### Common Issues

#### "Access Denied" Errors
- **Cause**: Script requires administrator privileges to read MFT
- **Solution**: Run PowerShell as Administrator

#### "Drive not found" Error
- **Cause**: Specified drive letter doesn't exist
- **Solution**: Check available drives with `Get-PSDrive -PSProvider FileSystem`

#### Slow Duplicate Detection
- **Cause**: Large number of files meeting minimum size threshold
- **Solution**: Increase `-MinDuplicateSize` (e.g., 50MB or 100MB)

#### Empty Results
- **Cause**: MaxDepth too shallow or Top too small
- **Solution**: Increase `-MaxDepth` and `-Top` parameters

#### MFT Compilation Error
- **Cause**: .NET Framework issue or missing dependencies
- **Solution**: Ensure .NET Framework 4.5+ is installed

### Error Categories

The script tracks errors in these categories:
- `access`: Permission denied errors
- `io`: Input/output errors (disk issues)
- `timeout`: Operation timeout errors
- `unknown`: Unclassified errors

View error summary in verbose output or HTML report.

---

## Version History

| Version | Changes |
|---------|---------|
| 9.0.0 | Enhanced duplicate detection: 3-stage pipeline with xxHash64, streaming full-file hashing, buffer pooling, dynamic memory management |
| 8.0.0 | Major refactor: centralized config, data-driven cleanup categories, unified theme system, template-based HTML, structured error handling, input validation, Pester tests |
| 7.x | Previous version with duplicate detection and NinjaOne integration |

---

## Technical Deep Dive

This section explains the internals of how the script achieves its performance.

### MFT (Master File Table) Enumeration

Traditional file system scanning uses recursive directory traversal, which requires:
- Opening each directory
- Reading directory entries
- Recursively descending into subdirectories
- Making thousands of individual I/O operations

**CF-UltraTreesizeNinja bypasses this entirely** by reading directly from the NTFS Master File Table.

#### How MFT Reading Works

1. **Direct Volume Access**: The script opens the volume as a raw device (`\\.\C:`) using `CreateFile` with `GENERIC_READ` access.

2. **USN Journal Query**: Uses `DeviceIoControl` with `FSCTL_QUERY_USN_JOURNAL` to get journal information and `FSCTL_ENUM_USN_DATA` to enumerate all file records.

3. **Single Sequential Read**: The entire MFT is read in one sequential pass using a 256KB buffer, returning all file metadata in seconds.

4. **Path Reconstruction**: File records contain parent directory references. The script builds a lookup table of directory references and reconstructs full paths by walking up the parent chain.

```
Traditional Scan: ~5-10 minutes for 500,000 files
MFT Enumeration:  ~1-3 seconds for 500,000 files
```

#### Requirements for MFT Access

- **Administrator privileges** (required to open volume handle)
- **NTFS file system** (MFT is NTFS-specific)
- **Windows OS** (uses Windows API calls)

---

### Duplicate Detection with xxHash64

The script uses a 3-stage pipeline to efficiently find duplicate files while minimizing disk I/O.

#### Stage 1: Size Filtering

Files are grouped by exact size. Only files with identical sizes can be duplicates.

```
500,000 files → Group by size → 12,000 files in 4,000 groups
```

This eliminates ~97% of files with zero disk reads.

#### Stage 2: Quick Hash (8KB xxHash64)

For each size group with 2+ files, compute xxHash64 of the first 8KB:

```csharp
// Read only first 8KB of file
fs.Read(buffer, 0, 8192);
ulong quickHash = XXHash64(buffer, bytesRead);
```

Files with different headers cannot be duplicates. This eliminates most remaining candidates.

```
12,000 files → Quick hash → 500 files in 150 groups
```

#### Stage 3: Full File Hash (Streaming xxHash64)

For remaining candidates, compute xxHash64 of the entire file:

```csharp
// Stream through file with 256KB buffer
while ((bytesRead = fs.Read(buffer, 0, 262144)) > 0)
{
    hash = XXHash64Streaming(hash, buffer, bytesRead);
}
return XXHash64Finalize(hash, totalLength);
```

Files with identical full hashes are duplicates.

#### Why xxHash64?

| Algorithm | Speed | Collision Rate | Use Case |
|-----------|-------|----------------|----------|
| MD5 | ~500 MB/s | 1 in 2^128 | Cryptographic (slow) |
| SHA-256 | ~300 MB/s | 1 in 2^256 | Cryptographic (slower) |
| **xxHash64** | **~10 GB/s** | 1 in 2^64 | Non-crypto (ideal) |

xxHash64 is:
- **20x faster** than cryptographic hashes
- **Perfect for deduplication** where we need speed, not security
- **Negligible collision risk**: With size + xxHash64, probability of false positive is ~1 in 10^19

#### xxHash64 Implementation

The script includes a complete C# implementation of xxHash64:

```csharp
// Core constants (prime numbers)
const ulong PRIME64_1 = 11400714785074694791UL;
const ulong PRIME64_2 = 14029467366897019727UL;
// ... (5 primes total)

// For files > 32 bytes: 4-way parallel accumulation
v1 = Round(v1, ReadLE64(data, offset));
v2 = Round(v2, ReadLE64(data, offset + 8));
v3 = Round(v3, ReadLE64(data, offset + 16));
v4 = Round(v4, ReadLE64(data, offset + 24));

// Final merge and avalanche
hash = MergeRound(hash, v1);
hash = MergeRound(hash, v2);
hash = MergeRound(hash, v3);
hash = MergeRound(hash, v4);
```

---

### Smart Memory Management

The script dynamically manages memory to prevent out-of-memory conditions while maximizing performance.

#### Buffer Pooling

Creating/destroying buffers causes garbage collection pressure. The script uses a `BufferPool` to reuse buffers:

```csharp
public static class BufferPool
{
    private const int SMALL_BUFFER = 8192;      // 8KB for quick hash
    private const int LARGE_BUFFER = 262144;    // 256KB for streaming
    private const int MAX_POOLED = 64;          // Max buffers per size

    private static readonly ConcurrentBag<byte[]> _smallBuffers;
    private static readonly ConcurrentBag<byte[]> _largeBuffers;

    public static byte[] RentSmall() { ... }
    public static byte[] RentLarge() { ... }
    public static void Return(byte[] buffer) { ... }
}
```

**Benefits**:
- Buffers are reused across operations
- No allocation during hot paths
- Thread-safe via `ConcurrentBag`
- Automatic pool size limiting

#### Dynamic Memory Limits

The `MemoryManager` class monitors available RAM:

```csharp
public static class MemoryManager
{
    private const long MIN_FILE_LOAD = 50L * 1024 * 1024;   // 50MB min
    private const long MAX_FILE_LOAD = 1024L * 1024 * 1024; // 1GB max

    public static long GetAvailableMemory()
    {
        // Query system for available physical memory
        return new ComputerInfo().AvailablePhysicalMemory;
    }

    public static bool ShouldCleanup(long fileSize)
    {
        // Trigger cleanup when memory runs low
        return fileSize > 100 * 1024 * 1024 ||
               GetAvailableMemory() < 500 * 1024 * 1024;
    }
}
```

#### Cleanup Strategy

1. **After large file groups**: Force GC if memory is low
2. **Between stages**: Release pooled buffers
3. **At completion**: Full cleanup with `GC.Collect()`

```csharp
public static void ForceCleanup()
{
    GC.Collect();
    GC.WaitForPendingFinalizers();
    GC.Collect();
}
```

---

### Performance Characteristics

| Component | Bottleneck | Typical Speed |
|-----------|------------|---------------|
| MFT Scan | CPU | 500K files/sec |
| Quick Hash | Disk I/O | Limited by read speed |
| Full Hash | Disk I/O | ~550 MB/s (SATA) or ~3500 MB/s (NVMe) |
| Hash Compare | CPU | Instant (in-memory) |

**Key insight**: With fast NVMe drives, CPU becomes the bottleneck. With SATA SSDs or HDDs, disk I/O is always the bottleneck. The code is optimized for both scenarios:

- **Sequential reads** (`FileOptions.SequentialScan`) for disk prefetch optimization
- **Large buffers** (256KB) to minimize syscalls
- **Parallel processing** for CPU-bound operations
- **Early filtering** to minimize total bytes read

---

## License

Internal use - Designed for NinjaOne RMM deployment and standalone usage.

---

## Support

For issues or feature requests, submit as a Github issue or pr.
