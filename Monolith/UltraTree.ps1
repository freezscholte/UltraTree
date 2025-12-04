<#
.SYNOPSIS
    Ultra-fast folder size calculation using USN Journal / MFT enumeration.

.DESCRIPTION
    V9 - Enhanced duplicate detection:
    - 3-stage duplicate detection: Size → Quick Hash (xxHash64) → Full Memory Compare
    - Dynamic memory management based on available RAM
    - Smart GC cleanup after large file comparisons
    - OOM fallback to streaming for huge files

    Inherited from V8:
    - Centralized configuration with nested theme/thresholds
    - Data-driven cleanup category detection
    - Unified theme system for icons/colors
    - Template-based HTML generation
    - Structured error handling with categories
    - Input validation layer

.PARAMETER TestMode
    When specified, script loads functions but does not execute main scan.
    Used for Pester testing.

.NOTES
    Version: 9.0.0
#>

param(
    [switch]$TestMode
)

#region Configuration

$script:Config = @{
    Version = "9.0.0"

    # Size thresholds
    Thresholds = @{
        CleanupMin      = 100MB     # Minimum size for cleanup suggestions
        DuplicateMin    = 10MB      # Minimum file size for duplicate detection
        LargeFile       = 100MB     # Files above this shown in results
        DangerWasted    = 500MB     # Wasted space threshold for "danger" severity
        WarningWasted   = 100MB     # Wasted space threshold for "warning" severity
        ErrorWarning    = 50       # Show warning if more than X files couldn't be read
    }

    # Display limits
    Display = @{
        MaxDuplicateGroups = 20     # Max duplicate groups to display
        MaxPathsPerGroup   = 5      # Max paths shown per duplicate group
        MaxTopFolders      = 8      # Top folders in bar chart
        MaxFileTypes       = 10     # Top file types to show
        MaxResults         = 40     # Max items in results table
        MaxPathLength      = 50     # Truncate paths longer than this
        MaxLabelLength     = 12     # Truncate chart labels longer than this
    }

    # Disk health thresholds (percent)
    DiskHealth = @{
        CriticalPercent = 90
        WarningPercent  = 75
    }

    # Size category thresholds for row styling
    SizeCategories = @{
        Danger  = 100GB
        Warning = 50GB
        Other   = 10GB
        Unknown = 1GB
    }

    # Theme: centralized colors and icons
    Theme = @{
        Colors = @{
            Danger   = "#d9534f"
            Warning  = "#f0ad4e"
            Info     = "#5bc0de"
            Success  = "#4ECDC4"
            Primary  = "#337ab7"
            Muted    = "#999999"
            Critical = "#FF6B6B"
            Free     = "#95a5a6"
        }
        Icons = @{
            # Status icons
            Info       = "fa-solid fa-circle-info"
            Warning    = "fa-solid fa-triangle-exclamation"
            Error      = "fa-solid fa-circle-exclamation"
            Success    = "fa-solid fa-circle-check"
            # Object icons
            Folder     = "fas fa-folder"
            File       = "fas fa-file"
            FileAlt    = "fas fa-file-alt"
            Drive      = "fas fa-hdd"
            List       = "fas fa-list"
            Chart      = "fas fa-chart-bar"
            Copy       = "fas fa-copy"
            Broom      = "fas fa-broom"
            Search     = "fas fa-search"
            CheckCircle = "fas fa-check-circle"
            # Category icons
            Trash      = "fas fa-trash"
            Clock      = "fas fa-clock"
            Database   = "fas fa-database"
            Code       = "fas fa-code"
            CodeBranch = "fas fa-code-branch"
            Download   = "fas fa-download"
            Cog        = "fas fa-cog"
        }
    }
}

# Data-driven cleanup categories (replaces 7-way if chain)
$script:CleanupCategories = @(
    @{
        Name        = "recycleBin"
        DisplayName = "Recycle Bin"
        Patterns    = @('\$Recycle.Bin', '\RECYCLER')
        Icon        = "Trash"
        Severity    = "Warning"
        Description = "Empty recycle bin to reclaim space"
    }
    @{
        Name        = "temp"
        DisplayName = "Temp Files"
        Patterns    = @('\Temp\', '\tmp\', '\AppData\Local\Temp')
        Icon        = "Clock"
        Severity    = "Info"
        Description = "Temporary files that can be safely deleted"
    }
    @{
        Name        = "cache"
        DisplayName = "Cache Files"
        Patterns    = @('\Cache\', '\cache\', '\.cache\', '\CachedData')
        Icon        = "Database"
        Severity    = "Info"
        Description = "Application cache files"
    }
    @{
        Name        = "nodeModules"
        DisplayName = "node_modules"
        Patterns    = @('\node_modules\')
        Icon        = "Code"
        Severity    = "Info"
        Description = "Node.js dependencies - run 'npm install' to restore"
    }
    @{
        Name        = "git"
        DisplayName = ".git folders"
        Patterns    = @('\.git\')
        Icon        = "CodeBranch"
        Severity    = "Info"
        Description = "Git repository data"
    }
    @{
        Name        = "downloads"
        DisplayName = "Downloads"
        Patterns    = @('\Downloads\')
        Icon        = "Download"
        Severity    = "Warning"
        Description = "Review and clean old downloads"
    }
    @{
        Name        = "installer"
        DisplayName = "Windows Installer"
        Patterns    = @('\Windows\Installer\')
        Icon        = "Cog"
        Severity    = "Danger"
        Description = "Windows Installer cache (use Disk Cleanup)"
    }
)

#endregion

#region Error Tracking

$script:ErrorLog = [System.Collections.Generic.List[PSCustomObject]]::new()

function Add-ScanError {
    param (
        [string]$Path,
        [ValidateSet("access", "io", "timeout", "unknown")]
        [string]$Category = "unknown",
        [string]$Message = ""
    )
    $script:ErrorLog.Add([PSCustomObject]@{
        Timestamp = Get-Date
        Path      = $Path
        Category  = $Category
        Message   = $Message
    })
}

function Get-ErrorSummary {
    $total = $script:ErrorLog.Count
    if ($total -eq 0) { return $null }

    $byCategory = $script:ErrorLog | Group-Object -Property Category
    $summary = ($byCategory | ForEach-Object {
        "$($_.Count) $($_.Name)"
    }) -join ", "

    return "$total errors: $summary"
}

function Clear-ErrorLog {
    $script:ErrorLog.Clear()
}

#endregion

#region Input Validation

function Test-ScanParameters {
    param (
        [string]$DriveLetter,
        [int]$MaxDepth,
        [int]$Top,
        [long]$MinDuplicateSize,
        [switch]$AllDrives
    )

    $errors = [System.Collections.Generic.List[string]]::new()

    # Validate drive letter if specified
    if ($DriveLetter -and -not $AllDrives) {
        $drivePath = "${DriveLetter}:\"
        if (-not (Test-Path $drivePath)) {
            $errors.Add("Drive '$DriveLetter' does not exist or is not accessible")
        }
    }

    # Validate MaxDepth
    if ($MaxDepth -lt 1) {
        $errors.Add("MaxDepth must be at least 1 (got: $MaxDepth)")
    }
    if ($MaxDepth -gt 20) {
        $errors.Add("MaxDepth cannot exceed 20 (got: $MaxDepth)")
    }

    # Validate Top
    if ($Top -lt 1) {
        $errors.Add("Top must be at least 1 (got: $Top)")
    }
    if ($Top -gt 1000) {
        $errors.Add("Top cannot exceed 1000 (got: $Top)")
    }

    # Validate MinDuplicateSize
    if ($MinDuplicateSize -lt 0) {
        $errors.Add("MinDuplicateSize cannot be negative (got: $MinDuplicateSize)")
    }

    if ($errors.Count -gt 0) {
        throw "Parameter validation failed:`n$($errors -join "`n")"
    }
}

#endregion

#region Helper Functions

function Format-ByteSize {
    <#
    .SYNOPSIS
        Formats byte count as human-readable size string.
    .DESCRIPTION
        Single unified implementation used throughout the script.
        Replaces both the C# FormatSize and PowerShell Convert-BytesToSize.
    #>
    param (
        [long]$Bytes,
        [int]$Decimals = 2
    )

    if ($Bytes -eq 0) { return "0 B" }

    $sizes = @("B", "KB", "MB", "GB", "TB", "PB")
    $order = 0
    $size = [double]$Bytes

    while ($size -ge 1024 -and $order -lt $sizes.Count - 1) {
        $order++
        $size /= 1024
    }

    "{0:N$Decimals} {1}" -f $size, $sizes[$order]
}

function Get-ThemeColor {
    <#
    .SYNOPSIS
        Returns color from theme by severity name.
    #>
    param (
        [ValidateSet("Danger", "Warning", "Info", "Success", "Primary", "Muted", "Critical", "Free")]
        [string]$Severity
    )
    $script:Config.Theme.Colors[$Severity]
}

function Get-ThemeIcon {
    <#
    .SYNOPSIS
        Returns icon class from theme by icon name.
    #>
    param ([string]$IconName)
    $script:Config.Theme.Icons[$IconName]
}

function Get-SeverityStyle {
    <#
    .SYNOPSIS
        Returns hashtable with Color, Icon, and Class for a severity level.
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

function Get-SizeCategory {
    <#
    .SYNOPSIS
        Returns CSS class based on size thresholds.
    #>
    param ([long]$SizeBytes)

    $cfg = $script:Config.SizeCategories
    switch ($SizeBytes) {
        { $_ -gt $cfg.Danger }  { return "danger" }
        { $_ -gt $cfg.Warning } { return "warning" }
        { $_ -gt $cfg.Other }   { return "other" }
        { $_ -gt $cfg.Unknown } { return "unknown" }
        default                 { return "success" }
    }
}

function Get-DiskHealthTag {
    <#
    .SYNOPSIS
        Returns health status based on disk usage percent.
    #>
    param ([double]$UsedPercent)

    $cfg = $script:Config.DiskHealth
    if ($UsedPercent -gt $cfg.CriticalPercent) {
        return @{ Class = "expired"; Text = "Critical" }
    }
    elseif ($UsedPercent -gt $cfg.WarningPercent) {
        return @{ Class = "disabled"; Text = "Warning" }
    }
    else {
        return @{ Class = ""; Text = "Healthy" }
    }
}

function Get-DiskUsedColor {
    <#
    .SYNOPSIS
        Returns appropriate color for disk usage based on percent.
    #>
    param ([double]$UsedPercent)

    $cfg = $script:Config.DiskHealth
    if ($UsedPercent -gt $cfg.CriticalPercent) {
        return Get-ThemeColor -Severity "Critical"
    }
    elseif ($UsedPercent -gt $cfg.WarningPercent) {
        return Get-ThemeColor -Severity "Warning"
    }
    else {
        return Get-ThemeColor -Severity "Success"
    }
}

function Get-WastedSpaceSeverity {
    <#
    .SYNOPSIS
        Returns severity level based on wasted space amount.
    #>
    param ([long]$WastedBytes)

    $cfg = $script:Config.Thresholds
    if ($WastedBytes -gt $cfg.DangerWasted) { return "Danger" }
    elseif ($WastedBytes -gt $cfg.WarningWasted) { return "Warning" }
    else { return "Info" }
}

function Get-CleanupCategoryInfo {
    <#
    .SYNOPSIS
        Returns cleanup category info by name.
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

#endregion

#region C# Scanner

Add-Type -TypeDefinition @"
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Runtime.InteropServices;
using System.ComponentModel;
using Microsoft.Win32.SafeHandles;
using System.Diagnostics;

namespace MftTreeSizeV8
{
    public class FolderResult
    {
        public string Path;
        public long Size;
        public bool IsDirectory;
        public DateTime LastModified;
    }

    public class FileTypeInfo
    {
        public string Extension;
        public long TotalSize;
        public int FileCount;
    }

    public class CleanupSuggestion
    {
        public string Path;
        public string Category;
        public long Size;
        public string Description;
    }

    public class DuplicateGroup
    {
        public string Hash;
        public long FileSize;
        public List<string> Files;
        public long WastedSpace;
    }

    public class DuplicateResult
    {
        public List<DuplicateGroup> Groups;
        public long TotalWastedSpace;
        public int TotalDuplicateFiles;

        public DuplicateResult()
        {
            Groups = new List<DuplicateGroup>();
            TotalWastedSpace = 0;
            TotalDuplicateFiles = 0;
        }
    }

    public class ScanResult
    {
        public List<FolderResult> Items;
        public List<FileTypeInfo> FileTypes;
        public List<CleanupSuggestion> CleanupSuggestions;
        public DuplicateResult Duplicates;
        public long TotalUsedSpace;
        public long TotalFreeSpace;
        public long TotalDriveSize;
        public long ErrorCount;
        public long TotalFiles;
        public long TotalFolders;
    }

    // Memory manager for dynamic RAM-based file loading
    public static class MemoryManager
    {
        private const long MIN_FILE_LOAD = 50L * 1024 * 1024;      // 50MB minimum
        private const long MAX_FILE_LOAD = 1024L * 1024 * 1024;    // 1GB maximum
        private const long CLEANUP_THRESHOLD = 50L * 1024 * 1024;  // Cleanup after 50MB files

        public static long GetAvailableMemory()
        {
            try
            {
                // Use GC to estimate available memory
                long totalMemory = GC.GetTotalMemory(false);
                // Assume 80% of max memory is usable, minus current usage
                long maxMemory = Environment.Is64BitProcess ? 8L * 1024 * 1024 * 1024 : 1536L * 1024 * 1024;
                return Math.Max(maxMemory - totalMemory, MIN_FILE_LOAD);
            }
            catch
            {
                return MIN_FILE_LOAD;
            }
        }

        public static long GetMaxFileLoadSize()
        {
            long available = GetAvailableMemory();
            // Use 25% of available, capped between min and max
            long maxLoad = available / 4;
            return Math.Max(Math.Min(maxLoad, MAX_FILE_LOAD), MIN_FILE_LOAD);
        }

        public static bool ShouldCleanup(long fileSize)
        {
            return fileSize > CLEANUP_THRESHOLD;
        }

        public static void Cleanup()
        {
            GC.Collect(2, GCCollectionMode.Optimized, false);
        }

        public static void ForceCleanup()
        {
            GC.Collect(2, GCCollectionMode.Forced, true);
            GC.WaitForPendingFinalizers();
        }
    }

    // Simple buffer pool to reduce GC pressure during file operations
    public static class BufferPool
    {
        private const int SMALL_BUFFER = 8192;      // 8KB for quick hash
        private const int LARGE_BUFFER = 262144;    // 256KB for streaming
        private const int MAX_POOLED = 64;          // Max buffers to keep per size

        private static readonly ConcurrentBag<byte[]> _smallBuffers = new ConcurrentBag<byte[]>();
        private static readonly ConcurrentBag<byte[]> _largeBuffers = new ConcurrentBag<byte[]>();

        public static byte[] RentSmall()
        {
            byte[] buffer;
            if (_smallBuffers.TryTake(out buffer))
                return buffer;
            return new byte[SMALL_BUFFER];
        }

        public static byte[] RentLarge()
        {
            byte[] buffer;
            if (_largeBuffers.TryTake(out buffer))
                return buffer;
            return new byte[LARGE_BUFFER];
        }

        public static void Return(byte[] buffer)
        {
            if (buffer == null) return;

            if (buffer.Length == SMALL_BUFFER && _smallBuffers.Count < MAX_POOLED)
                _smallBuffers.Add(buffer);
            else if (buffer.Length == LARGE_BUFFER && _largeBuffers.Count < MAX_POOLED)
                _largeBuffers.Add(buffer);
            // Otherwise let GC collect it
        }

        public static void Clear()
        {
            byte[] dummy;
            while (_smallBuffers.TryTake(out dummy)) { }
            while (_largeBuffers.TryTake(out dummy)) { }
        }
    }

    public static class DuplicateFinder
    {
        private const int QUICK_HASH_SIZE = 8192;  // 8KB for quick hash
        private static readonly int[] BLOCK_SIZES = { 4096, 8192, 16384, 32768, 65536, 131072, 262144 };

        // xxHash64 constants
        private const ulong PRIME64_1 = 11400714785074694791UL;
        private const ulong PRIME64_2 = 14029467366897019727UL;
        private const ulong PRIME64_3 = 1609587929392839161UL;
        private const ulong PRIME64_4 = 9650029242287828579UL;
        private const ulong PRIME64_5 = 2870177450012600261UL;

        public static DuplicateResult FindDuplicates(
            string[] filePaths,
            long[] fileSizes,
            long minFileSize,
            bool verbose)
        {
            var result = new DuplicateResult();
            var totalSw = Stopwatch.StartNew();

            // ============ STAGE 1: Group by size ============
            var sw = Stopwatch.StartNew();
            var sizeGroups = new Dictionary<long, List<int>>();
            for (int i = 0; i < filePaths.Length; i++)
            {
                if (fileSizes[i] < minFileSize) continue;
                if (!sizeGroups.ContainsKey(fileSizes[i]))
                    sizeGroups[fileSizes[i]] = new List<int>();
                sizeGroups[fileSizes[i]].Add(i);
            }

            var sizeCandidates = sizeGroups.Where(g => g.Value.Count >= 2).ToList();
            int stage1Files = sizeCandidates.Sum(g => g.Value.Count);
            int stage1Groups = sizeCandidates.Count;

            sw.Stop();
            if (verbose) Console.WriteLine("  Stage 1 (size filter): {0:N0} files in {1:N0} groups | {2:N2}s",
                stage1Files, stage1Groups, sw.Elapsed.TotalSeconds);

            if (sizeCandidates.Count == 0) return result;

            // ============ STAGE 2: Quick hash (xxHash64 of first 8KB) ============
            sw.Restart();
            var hashCandidates = new ConcurrentBag<KeyValuePair<long, List<string>>>();
            long hashErrors = 0;

            Parallel.ForEach(sizeCandidates, new ParallelOptions { MaxDegreeOfParallelism = Environment.ProcessorCount }, group =>
            {
                var hashGroups = new Dictionary<ulong, List<string>>();
                long fileSize = group.Key;

                foreach (int idx in group.Value)
                {
                    try
                    {
                        ulong hash = ComputeQuickHash(filePaths[idx], fileSize);
                        if (!hashGroups.ContainsKey(hash))
                            hashGroups[hash] = new List<string>();
                        hashGroups[hash].Add(filePaths[idx]);
                    }
                    catch
                    {
                        Interlocked.Increment(ref hashErrors);
                    }
                }

                // Only keep groups with 2+ files (potential duplicates)
                foreach (var hg in hashGroups.Where(h => h.Value.Count >= 2))
                {
                    hashCandidates.Add(new KeyValuePair<long, List<string>>(fileSize, hg.Value));
                }
            });

            int stage2Files = hashCandidates.Sum(g => g.Value.Count);
            int stage2Groups = hashCandidates.Count;

            sw.Stop();
            if (verbose) Console.WriteLine("  Stage 2 (quick hash): {0:N0} files in {1:N0} groups, {2:N0} errors | {3:N2}s",
                stage2Files, stage2Groups, hashErrors, sw.Elapsed.TotalSeconds);

            if (hashCandidates.Count == 0) return result;

            // ============ STAGE 3: Full file hash comparison ============
            sw.Restart();
            var allDuplicateSets = new ConcurrentBag<DuplicateGroup>();
            long totalComparisons = 0;

            Parallel.ForEach(hashCandidates, new ParallelOptions { MaxDegreeOfParallelism = Math.Max(1, Environment.ProcessorCount / 2) }, group =>
            {
                var files = group.Value;
                long fileSize = group.Key;

                var duplicateSets = FindDuplicatesInGroup(files, fileSize, ref totalComparisons);
                foreach (var dupSet in duplicateSets)
                    allDuplicateSets.Add(dupSet);

                // Cleanup after large files
                if (MemoryManager.ShouldCleanup(fileSize))
                    MemoryManager.Cleanup();
            });

            foreach (var dupGroup in allDuplicateSets)
            {
                result.Groups.Add(dupGroup);
                result.TotalWastedSpace += dupGroup.WastedSpace;
                result.TotalDuplicateFiles += dupGroup.Files.Count;
            }

            result.Groups = result.Groups.OrderByDescending(g => g.WastedSpace).ToList();

            sw.Stop();
            totalSw.Stop();
            if (verbose)
            {
                Console.WriteLine("  Stage 3 (full hash): {0:N0} groups, {1:N0} comparisons | {2:N2}s",
                    result.Groups.Count, totalComparisons, sw.Elapsed.TotalSeconds);
                Console.WriteLine("  Duplicate scan total: {0:N2}s", totalSw.Elapsed.TotalSeconds);
            }

            // Final cleanup - release pooled buffers and force GC
            BufferPool.Clear();
            MemoryManager.ForceCleanup();

            return result;
        }

        private static ulong ComputeQuickHash(string filePath, long fileSize)
        {
            int bytesToRead = (int)Math.Min(QUICK_HASH_SIZE, fileSize);
            byte[] buffer = BufferPool.RentSmall();

            try
            {
                using (var fs = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read, QUICK_HASH_SIZE, FileOptions.SequentialScan))
                {
                    fs.Read(buffer, 0, bytesToRead);
                }

                return XXHash64(buffer, bytesToRead);
            }
            finally
            {
                BufferPool.Return(buffer);
            }
        }

        private static ulong XXHash64(byte[] data, int length)
        {
            unchecked
            {
                ulong h64;
                int index = 0;

                if (length >= 32)
                {
                    ulong v1 = PRIME64_1 + PRIME64_2;
                    ulong v2 = PRIME64_2;
                    ulong v3 = 0;
                    ulong v4 = (ulong)-(long)PRIME64_1;

                    int limit = length - 32;
                    do
                    {
                        v1 = Round(v1, BitConverter.ToUInt64(data, index)); index += 8;
                        v2 = Round(v2, BitConverter.ToUInt64(data, index)); index += 8;
                        v3 = Round(v3, BitConverter.ToUInt64(data, index)); index += 8;
                        v4 = Round(v4, BitConverter.ToUInt64(data, index)); index += 8;
                    } while (index <= limit);

                    h64 = RotateLeft(v1, 1) + RotateLeft(v2, 7) + RotateLeft(v3, 12) + RotateLeft(v4, 18);
                    h64 = MergeRound(h64, v1);
                    h64 = MergeRound(h64, v2);
                    h64 = MergeRound(h64, v3);
                    h64 = MergeRound(h64, v4);
                }
                else
                {
                    h64 = PRIME64_5;
                }

                h64 += (ulong)length;

                // Process remaining bytes
                int remaining = length - index;
                while (remaining >= 8)
                {
                    h64 ^= Round(0, BitConverter.ToUInt64(data, index));
                    h64 = RotateLeft(h64, 27) * PRIME64_1 + PRIME64_4;
                    index += 8;
                    remaining -= 8;
                }
                while (remaining >= 4)
                {
                    h64 ^= BitConverter.ToUInt32(data, index) * PRIME64_1;
                    h64 = RotateLeft(h64, 23) * PRIME64_2 + PRIME64_3;
                    index += 4;
                    remaining -= 4;
                }
                while (remaining > 0)
                {
                    h64 ^= data[index] * PRIME64_5;
                    h64 = RotateLeft(h64, 11) * PRIME64_1;
                    index++;
                    remaining--;
                }

                // Final avalanche
                h64 ^= h64 >> 33;
                h64 *= PRIME64_2;
                h64 ^= h64 >> 29;
                h64 *= PRIME64_3;
                h64 ^= h64 >> 32;

                return h64;
            }
        }

        private static ulong Round(ulong acc, ulong input)
        {
            unchecked
            {
                acc += input * PRIME64_2;
                acc = RotateLeft(acc, 31);
                acc *= PRIME64_1;
                return acc;
            }
        }

        private static ulong MergeRound(ulong acc, ulong val)
        {
            unchecked
            {
                val = Round(0, val);
                acc ^= val;
                acc = acc * PRIME64_1 + PRIME64_4;
                return acc;
            }
        }

        private static ulong RotateLeft(ulong value, int count)
        {
            return (value << count) | (value >> (64 - count));
        }

        // Compute full file xxHash64 using streaming (256KB chunks)
        private static ulong ComputeFullHash(string filePath)
        {
            byte[] buffer = BufferPool.RentLarge();
            try
            {
                using (var fs = new FileStream(filePath, FileMode.Open, FileAccess.Read,
                       FileShare.Read, 262144, FileOptions.SequentialScan))
                {
                    long fileLength = fs.Length;

                    // For files that fit in buffer, use direct hash
                    if (fileLength <= 262144)
                    {
                        int bytesRead = fs.Read(buffer, 0, (int)fileLength);
                        return XXHash64(buffer, bytesRead);
                    }

                    // For larger files, use streaming hash
                    unchecked
                    {
                        ulong v1 = PRIME64_1 + PRIME64_2;
                        ulong v2 = PRIME64_2;
                        ulong v3 = 0;
                        ulong v4 = (ulong)-(long)PRIME64_1;

                        int bytesRead;
                        long totalProcessed = 0;
                        byte[] remainder = null;
                        int remainderLen = 0;

                        while ((bytesRead = fs.Read(buffer, 0, 262144)) > 0)
                        {
                            int offset = 0;

                            // If we have leftover from previous chunk, combine
                            if (remainder != null && remainderLen > 0)
                            {
                                int needed = 32 - remainderLen;
                                if (bytesRead >= needed)
                                {
                                    byte[] combined = new byte[32];
                                    Array.Copy(remainder, 0, combined, 0, remainderLen);
                                    Array.Copy(buffer, 0, combined, remainderLen, needed);

                                    v1 = Round(v1, BitConverter.ToUInt64(combined, 0));
                                    v2 = Round(v2, BitConverter.ToUInt64(combined, 8));
                                    v3 = Round(v3, BitConverter.ToUInt64(combined, 16));
                                    v4 = Round(v4, BitConverter.ToUInt64(combined, 24));

                                    offset = needed;
                                    totalProcessed += 32;
                                }
                                remainder = null;
                                remainderLen = 0;
                            }

                            // Process complete 32-byte blocks
                            while (offset + 32 <= bytesRead)
                            {
                                v1 = Round(v1, BitConverter.ToUInt64(buffer, offset));
                                v2 = Round(v2, BitConverter.ToUInt64(buffer, offset + 8));
                                v3 = Round(v3, BitConverter.ToUInt64(buffer, offset + 16));
                                v4 = Round(v4, BitConverter.ToUInt64(buffer, offset + 24));
                                offset += 32;
                                totalProcessed += 32;
                            }

                            // Save remainder for next iteration
                            if (offset < bytesRead)
                            {
                                remainderLen = bytesRead - offset;
                                remainder = new byte[remainderLen];
                                Array.Copy(buffer, offset, remainder, 0, remainderLen);
                            }
                        }

                        // Finalize
                        ulong h64;
                        if (totalProcessed >= 32)
                        {
                            h64 = RotateLeft(v1, 1) + RotateLeft(v2, 7) + RotateLeft(v3, 12) + RotateLeft(v4, 18);
                            h64 = MergeRound(h64, v1);
                            h64 = MergeRound(h64, v2);
                            h64 = MergeRound(h64, v3);
                            h64 = MergeRound(h64, v4);
                        }
                        else
                        {
                            h64 = PRIME64_5;
                        }

                        h64 += (ulong)fileLength;

                        // Process remaining bytes
                        if (remainder != null && remainderLen > 0)
                        {
                            int idx = 0;
                            while (remainderLen - idx >= 8)
                            {
                                h64 ^= Round(0, BitConverter.ToUInt64(remainder, idx));
                                h64 = RotateLeft(h64, 27) * PRIME64_1 + PRIME64_4;
                                idx += 8;
                            }
                            while (remainderLen - idx >= 4)
                            {
                                h64 ^= BitConverter.ToUInt32(remainder, idx) * PRIME64_1;
                                h64 = RotateLeft(h64, 23) * PRIME64_2 + PRIME64_3;
                                idx += 4;
                            }
                            while (idx < remainderLen)
                            {
                                h64 ^= remainder[idx] * PRIME64_5;
                                h64 = RotateLeft(h64, 11) * PRIME64_1;
                                idx++;
                            }
                        }

                        // Final avalanche
                        h64 ^= h64 >> 33;
                        h64 *= PRIME64_2;
                        h64 ^= h64 >> 29;
                        h64 *= PRIME64_3;
                        h64 ^= h64 >> 32;

                        return h64;
                    }
                }
            }
            finally
            {
                BufferPool.Return(buffer);
            }
        }

        private static List<DuplicateGroup> FindDuplicatesInGroup(
            List<string> files,
            long fileSize,
            ref long totalComparisons)
        {
            var duplicateSets = new List<List<string>>();
            var processed = new HashSet<int>();

            // Pre-compute hashes for all files in the group (more efficient)
            var fileHashes = new Dictionary<int, ulong>();
            for (int i = 0; i < files.Count; i++)
            {
                try
                {
                    fileHashes[i] = ComputeFullHash(files[i]);
                }
                catch
                {
                    // Skip files we can't read
                }
            }

            for (int i = 0; i < files.Count; i++)
            {
                if (processed.Contains(i)) continue;
                if (!fileHashes.ContainsKey(i)) continue;

                var currentSet = new List<string> { files[i] };

                for (int j = i + 1; j < files.Count; j++)
                {
                    if (processed.Contains(j)) continue;
                    if (!fileHashes.ContainsKey(j)) continue;

                    Interlocked.Increment(ref totalComparisons);

                    // Compare hashes (instant - no disk I/O)
                    if (fileHashes[i] == fileHashes[j])
                    {
                        currentSet.Add(files[j]);
                        processed.Add(j);
                    }
                }

                if (currentSet.Count > 1)
                    duplicateSets.Add(currentSet);
                processed.Add(i);
            }

            return duplicateSets.Select(set => new DuplicateGroup
            {
                Hash = fileHashes.ContainsKey(files.IndexOf(set[0])) ? fileHashes[files.IndexOf(set[0])].ToString("X16") : "MATCH",
                FileSize = fileSize,
                Files = set,
                WastedSpace = (set.Count - 1) * fileSize
            }).ToList();
        }
    }

    public class MftScanner
    {
        private const uint GENERIC_READ = 0x80000000;
        private const uint FILE_SHARE_READ = 0x00000001;
        private const uint FILE_SHARE_WRITE = 0x00000002;
        private const uint OPEN_EXISTING = 3;
        private const uint FSCTL_ENUM_USN_DATA = 0x000900B3;
        private const uint FSCTL_QUERY_USN_JOURNAL = 0x000900F4;
        private const int ERROR_HANDLE_EOF = 38;
        private const int MFT_ROOT_REFERENCE = 5;
        private const int MAX_PATH_DEPTH = 100;
        private const int MFT_BUFFER_SIZE = 256 * 1024;

        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        private static extern SafeFileHandle CreateFile(string lpFileName, uint dwDesiredAccess, uint dwShareMode, IntPtr lpSecurityAttributes, uint dwCreationDisposition, uint dwFlagsAndAttributes, IntPtr hTemplateFile);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool DeviceIoControl(SafeFileHandle hDevice, uint dwIoControlCode, IntPtr lpInBuffer, int nInBufferSize, IntPtr lpOutBuffer, int nOutBufferSize, out int lpBytesReturned, IntPtr lpOverlapped);

        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        private static extern uint GetCompressedFileSize(string lpFileName, out uint lpFileSizeHigh);

        [StructLayout(LayoutKind.Sequential)]
        private struct USN_JOURNAL_DATA { public ulong UsnJournalID; public long FirstUsn; public long NextUsn; public long LowestValidUsn; public long MaxUsn; public ulong MaximumSize; public ulong AllocationDelta; }

        [StructLayout(LayoutKind.Sequential)]
        private struct MFT_ENUM_DATA_V0 { public ulong StartFileReferenceNumber; public long LowUsn; public long HighUsn; }

        private struct MftEntry
        {
            public ulong FileRef;
            public ulong ParentRef;
            public string FileName;
            public bool IsDirectory;
            public long TimeStamp;
        }

        // Cleanup patterns - now passed from PowerShell via categories parameter
        public static ScanResult ScanWithAnalysis(
            string driveLetter,
            int maxDepth,
            int topN,
            bool includeFiles,
            bool verbose,
            bool findDuplicates,
            long minDuplicateSize,
            long largeFileThreshold,
            long cleanupMinSize,
            string[][] categoryPatterns,
            string[] categoryNames)
        {
            var result = new ScanResult
            {
                Items = new List<FolderResult>(),
                FileTypes = new List<FileTypeInfo>(),
                CleanupSuggestions = new List<CleanupSuggestion>(),
                Duplicates = new DuplicateResult()
            };

            driveLetter = driveLetter.TrimEnd(':');
            string volumePath = @"\\.\" + driveLetter + ":";
            string rootPath = driveLetter + ":\\";

            DriveInfo driveInfo = new DriveInfo(driveLetter);
            result.TotalDriveSize = driveInfo.TotalSize;
            result.TotalFreeSpace = driveInfo.TotalFreeSpace;
            result.TotalUsedSpace = driveInfo.TotalSize - driveInfo.TotalFreeSpace;

            var totalSw = Stopwatch.StartNew();

            if (!driveInfo.DriveFormat.Equals("NTFS", StringComparison.OrdinalIgnoreCase))
            {
                if (verbose) Console.WriteLine("Drive is not NTFS, using fallback");
                result.Items = ScanFallback(driveLetter, maxDepth, topN, includeFiles, largeFileThreshold, verbose);
                return result;
            }

            using (SafeFileHandle volumeHandle = CreateFile(volumePath, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE, IntPtr.Zero, OPEN_EXISTING, 0, IntPtr.Zero))
            {
                if (volumeHandle.IsInvalid)
                {
                    if (verbose) Console.WriteLine("Cannot open volume (need admin), using fallback");
                    result.Items = ScanFallback(driveLetter, maxDepth, topN, includeFiles, largeFileThreshold, verbose);
                    return result;
                }

                IntPtr journalDataPtr = Marshal.AllocHGlobal(64);
                int bytesReturned;
                bool success = DeviceIoControl(volumeHandle, FSCTL_QUERY_USN_JOURNAL, IntPtr.Zero, 0, journalDataPtr, 64, out bytesReturned, IntPtr.Zero);

                if (!success)
                {
                    Marshal.FreeHGlobal(journalDataPtr);
                    if (verbose) Console.WriteLine("USN Journal not available, using fallback");
                    result.Items = ScanFallback(driveLetter, maxDepth, topN, includeFiles, largeFileThreshold, verbose);
                    return result;
                }

                USN_JOURNAL_DATA journalData = (USN_JOURNAL_DATA)Marshal.PtrToStructure(journalDataPtr, typeof(USN_JOURNAL_DATA));
                Marshal.FreeHGlobal(journalDataPtr);

                // MFT Enumeration
                var sw = Stopwatch.StartNew();
                var fileMap = new Dictionary<ulong, MftEntry>(2000000);

                IntPtr buffer = Marshal.AllocHGlobal(MFT_BUFFER_SIZE);
                IntPtr enumDataPtr = Marshal.AllocHGlobal(24);

                try
                {
                    MFT_ENUM_DATA_V0 enumData = new MFT_ENUM_DATA_V0 { StartFileReferenceNumber = 0, LowUsn = 0, HighUsn = journalData.NextUsn };
                    Marshal.StructureToPtr(enumData, enumDataPtr, false);

                    while (true)
                    {
                        success = DeviceIoControl(volumeHandle, FSCTL_ENUM_USN_DATA, enumDataPtr, 24, buffer, MFT_BUFFER_SIZE, out bytesReturned, IntPtr.Zero);
                        if (!success) { if (Marshal.GetLastWin32Error() == ERROR_HANDLE_EOF) break; else break; }
                        if (bytesReturned <= 8) break;

                        ulong nextStartRef = (ulong)Marshal.ReadInt64(buffer);
                        int offset = 8;

                        while (offset < bytesReturned)
                        {
                            int recordLength = Marshal.ReadInt32(buffer, offset);
                            if (recordLength == 0) break;

                            ulong fileRef = (ulong)Marshal.ReadInt64(buffer, offset + 8) & 0x0000FFFFFFFFFFFF;
                            ulong parentRef = (ulong)Marshal.ReadInt64(buffer, offset + 16) & 0x0000FFFFFFFFFFFF;
                            long timeStamp = Marshal.ReadInt64(buffer, offset + 32);
                            uint fileAttributes = (uint)Marshal.ReadInt32(buffer, offset + 52);
                            short fileNameLength = Marshal.ReadInt16(buffer, offset + 56);
                            short fileNameOffset = Marshal.ReadInt16(buffer, offset + 58);
                            string fileName = Marshal.PtrToStringUni(IntPtr.Add(buffer, offset + fileNameOffset), fileNameLength / 2);

                            fileMap[fileRef] = new MftEntry { FileRef = fileRef, ParentRef = parentRef, FileName = fileName, IsDirectory = (fileAttributes & 0x10) != 0, TimeStamp = timeStamp };
                            offset += recordLength;
                        }

                        enumData.StartFileReferenceNumber = nextStartRef;
                        Marshal.StructureToPtr(enumData, enumDataPtr, false);
                    }
                }
                finally
                {
                    Marshal.FreeHGlobal(buffer);
                    Marshal.FreeHGlobal(enumDataPtr);
                }

                sw.Stop();
                if (verbose) Console.WriteLine("MFT enumeration: {0:N2}s ({1:N0} entries)", sw.Elapsed.TotalSeconds, fileMap.Count);

                // Build paths for directories
                sw.Restart();
                var pathCache = new Dictionary<ulong, string>(500000);
                pathCache[MFT_ROOT_REFERENCE] = rootPath;

                foreach (var entry in fileMap.Values)
                {
                    if (entry.IsDirectory)
                        GetFullPath(entry.FileRef, fileMap, pathCache, rootPath);
                }

                sw.Stop();
                if (verbose) Console.WriteLine("Directory paths: {0:N2}s ({1:N0} dirs)", sw.Elapsed.TotalSeconds, pathCache.Count);

                // Parallel size retrieval
                sw.Restart();
                var files = fileMap.Values.Where(e => !e.IsDirectory).ToArray();

                var folderSizesByRef = new ConcurrentDictionary<ulong, long>();
                var largeFiles = new ConcurrentBag<FolderResult>();
                var fileTypeSizes = new ConcurrentDictionary<string, long>();
                var fileTypeCounts = new ConcurrentDictionary<string, int>();

                var allFilePaths = findDuplicates ? new ConcurrentBag<string>() : null;
                var allFileSizes = findDuplicates ? new ConcurrentBag<long>() : null;

                // Dynamic cleanup tracking based on categories
                var categorySizes = new ConcurrentDictionary<string, long>();
                foreach (var name in categoryNames)
                    categorySizes[name] = 0;

                long errorCount = 0;

                Parallel.ForEach(files, new ParallelOptions { MaxDegreeOfParallelism = Environment.ProcessorCount }, entry =>
                {
                    string path = GetFullPathForFile(entry, fileMap, pathCache, rootPath);
                    if (path == null) return;

                    long size = 0;
                    try
                    {
                        uint high;
                        uint low = GetCompressedFileSize(path, out high);
                        if (low != 0xFFFFFFFF || Marshal.GetLastWin32Error() == 0)
                            size = ((long)high << 32) + low;
                        else
                        {
                            Interlocked.Increment(ref errorCount);
                            return;
                        }
                    }
                    catch
                    {
                        Interlocked.Increment(ref errorCount);
                        return;
                    }

                    if (findDuplicates && size >= minDuplicateSize)
                    {
                        allFilePaths.Add(path);
                        allFileSizes.Add(size);
                    }

                    string ext = Path.GetExtension(entry.FileName);
                    if (!string.IsNullOrEmpty(ext))
                    {
                        ext = ext.ToLowerInvariant();
                        fileTypeSizes.AddOrUpdate(ext, size, (k, v) => v + size);
                        fileTypeCounts.AddOrUpdate(ext, 1, (k, v) => v + 1);
                    }

                    // Track cleanup categories
                    for (int c = 0; c < categoryPatterns.Length; c++)
                    {
                        if (ContainsAny(path, categoryPatterns[c]))
                        {
                            categorySizes.AddOrUpdate(categoryNames[c], size, (k, v) => v + size);
                            break;
                        }
                    }

                    if (includeFiles && size >= largeFileThreshold)
                    {
                        DateTime lastMod = DateTime.MinValue;
                        try { lastMod = File.GetLastWriteTime(path); } catch { }
                        largeFiles.Add(new FolderResult { Path = path, Size = size, IsDirectory = false, LastModified = lastMod });
                    }

                    ulong parentRef = entry.ParentRef;
                    int depth = 0;
                    while (parentRef >= MFT_ROOT_REFERENCE && depth < MAX_PATH_DEPTH)
                    {
                        folderSizesByRef.AddOrUpdate(parentRef, size, (k, v) => v + size);

                        MftEntry parentEntry;
                        if (!fileMap.TryGetValue(parentRef, out parentEntry)) break;
                        if (parentEntry.ParentRef == MFT_ROOT_REFERENCE && parentRef == MFT_ROOT_REFERENCE) break;
                        if (parentEntry.ParentRef == parentRef) break;

                        parentRef = parentEntry.ParentRef;
                        depth++;
                    }
                });

                sw.Stop();
                if (verbose) Console.WriteLine("Size + aggregation: {0:N2}s ({1:N0} files, {2:N0} errors)", sw.Elapsed.TotalSeconds, files.Length, errorCount);

                // Duplicate detection
                if (findDuplicates && allFilePaths != null && allFilePaths.Count > 0)
                {
                    sw.Restart();
                    if (verbose) Console.WriteLine("Duplicate detection: {0:N0} files >= {1} bytes", allFilePaths.Count, minDuplicateSize);

                    var pathsArray = allFilePaths.ToArray();
                    var sizesArray = allFileSizes.ToArray();

                    result.Duplicates = DuplicateFinder.FindDuplicates(pathsArray, sizesArray, minDuplicateSize, verbose);

                    sw.Stop();
                    if (verbose) Console.WriteLine("Duplicate scan complete: {0:N0} groups, {1} bytes wasted | {2:N2}s",
                        result.Duplicates.Groups.Count, result.Duplicates.TotalWastedSpace, sw.Elapsed.TotalSeconds);
                }

                // Build file type results
                result.FileTypes = fileTypeSizes
                    .Select(kvp => new FileTypeInfo { Extension = kvp.Key, TotalSize = kvp.Value, FileCount = fileTypeCounts.GetOrAdd(kvp.Key, 0) })
                    .OrderByDescending(f => f.TotalSize)
                    .Take(15)
                    .ToList();

                // Build cleanup suggestions from tracked categories
                foreach (var kvp in categorySizes)
                {
                    if (kvp.Value > cleanupMinSize)
                    {
                        result.CleanupSuggestions.Add(new CleanupSuggestion
                        {
                            Path = kvp.Key,
                            Category = kvp.Key,
                            Size = kvp.Value,
                            Description = ""
                        });
                    }
                }
                result.CleanupSuggestions = result.CleanupSuggestions.OrderByDescending(c => c.Size).ToList();

                // Convert folder refs to paths
                sw.Restart();
                var items = new List<FolderResult>();

                foreach (var kvp in folderSizesByRef)
                {
                    ulong folderRef = kvp.Key;
                    long size = kvp.Value;

                    string folderPath;
                    if (!pathCache.TryGetValue(folderRef, out folderPath))
                        folderPath = GetFullPath(folderRef, fileMap, pathCache, rootPath);

                    if (folderPath == null) continue;

                    int pathDepth = GetPathDepth(folderPath);
                    if (pathDepth <= maxDepth)
                    {
                        DateTime folderLastMod = DateTime.MinValue;
                        try { folderLastMod = Directory.GetLastWriteTime(folderPath); } catch { }
                        items.Add(new FolderResult { Path = NormalizePath(folderPath), Size = size, IsDirectory = true, LastModified = folderLastMod });
                    }
                }

                if (includeFiles)
                    items.AddRange(largeFiles);

                result.Items = items.OrderByDescending(r => r.Size).Take(topN).ToList();
                result.ErrorCount = errorCount;
                result.TotalFiles = files.Length;
                result.TotalFolders = pathCache.Count;

                sw.Stop();
                totalSw.Stop();
                if (verbose) Console.WriteLine("Results: {0:N2}s | TOTAL: {1:N2}s", sw.Elapsed.TotalSeconds, totalSw.Elapsed.TotalSeconds);
            }

            return result;
        }

        private static bool ContainsAny(string path, string[] patterns)
        {
            foreach (var pattern in patterns)
            {
                if (path.IndexOf(pattern, StringComparison.OrdinalIgnoreCase) >= 0)
                    return true;
            }
            return false;
        }

        private static string NormalizePath(string path)
        {
            if (string.IsNullOrEmpty(path)) return path;
            if (path.Length == 3 && path[1] == ':' && path[2] == '\\') return path;
            return path.TrimEnd('\\');
        }

        private static int GetPathDepth(string path)
        {
            if (string.IsNullOrEmpty(path)) return 0;
            int count = 0;
            for (int i = 0; i < path.Length; i++)
                if (path[i] == '\\') count++;
            return count;
        }

        private static string GetFullPathForFile(MftEntry entry, Dictionary<ulong, MftEntry> fileMap, Dictionary<ulong, string> pathCache, string rootPath)
        {
            string parentPath;
            if (!pathCache.TryGetValue(entry.ParentRef, out parentPath))
                parentPath = GetFullPath(entry.ParentRef, fileMap, pathCache, rootPath);
            if (parentPath == null) return null;
            return Path.Combine(parentPath, entry.FileName);
        }

        private static string GetFullPath(ulong fileRef, Dictionary<ulong, MftEntry> fileMap, Dictionary<ulong, string> pathCache, string rootPath)
        {
            string cached;
            if (pathCache.TryGetValue(fileRef, out cached)) return cached;

            MftEntry entry;
            if (!fileMap.TryGetValue(fileRef, out entry)) return null;

            if (entry.ParentRef == MFT_ROOT_REFERENCE || entry.FileRef == MFT_ROOT_REFERENCE)
            {
                string path = entry.FileRef == MFT_ROOT_REFERENCE ? rootPath : rootPath + entry.FileName;
                pathCache[fileRef] = path;
                return path;
            }
            if (entry.ParentRef < MFT_ROOT_REFERENCE) return null;

            string parentPath = GetFullPath(entry.ParentRef, fileMap, pathCache, rootPath);
            if (parentPath == null) return null;

            string fullPath = Path.Combine(parentPath, entry.FileName);
            pathCache[fileRef] = fullPath;
            return fullPath;
        }

        private static List<FolderResult> ScanFallback(string driveLetter, int maxDepth, int topN, bool includeFiles, long largeFileThreshold, bool verbose)
        {
            var results = new ConcurrentBag<FolderResult>();
            var rootDir = new DirectoryInfo(driveLetter + ":\\");
            ScanDirectoryFallback(rootDir, 0, maxDepth, includeFiles, largeFileThreshold, results, verbose);
            return results.OrderByDescending(r => r.Size).Take(topN).ToList();
        }

        private static long ScanDirectoryFallback(DirectoryInfo dir, int depth, int maxDepth, bool includeFiles, long largeFileThreshold, ConcurrentBag<FolderResult> results, bool verbose)
        {
            long totalSize = 0;
            try
            {
                foreach (var file in dir.EnumerateFiles())
                {
                    try
                    {
                        uint high;
                        uint low = GetCompressedFileSize(file.FullName, out high);
                        long size = ((long)high << 32) + low;
                        totalSize += size;
                        if (includeFiles && size >= largeFileThreshold)
                            results.Add(new FolderResult { Path = file.FullName, Size = size, IsDirectory = false });
                    }
                    catch { }
                }

                var subDirs = dir.EnumerateDirectories().ToArray();
                var subSizes = new long[subDirs.Length];
                Parallel.For(0, subDirs.Length, i => {
                    try { subSizes[i] = ScanDirectoryFallback(subDirs[i], depth + 1, maxDepth, includeFiles, largeFileThreshold, results, verbose); } catch { }
                });
                totalSize += subSizes.Sum();

                if (depth <= maxDepth)
                    results.Add(new FolderResult { Path = NormalizePath(dir.FullName), Size = totalSize, IsDirectory = true });
            }
            catch { }
            return totalSize;
        }
    }
}
"@

#endregion

#region HTML Generation Functions

function New-HtmlWrapper {
    <#
    .SYNOPSIS
        Wraps HTML fragment with full document including CSS/JS dependencies.
        Use for local testing - NinjaOne WYSIWYG fields already have these loaded.
    #>
    param (
        [string]$Content,
        [string]$Title = "TreeSize Report"
    )

    @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$Title</title>
    <!-- Bootstrap 5 -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <!-- Font Awesome 6 -->
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.2/css/all.min.css" rel="stylesheet">
    <!-- Charts.css -->
    <link href="https://cdn.jsdelivr.net/npm/charts.css/dist/charts.min.css" rel="stylesheet">
    <style>
        body {
            background-color: #f5f7fa;
            color: #333;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            padding: 20px;
        }
        .card {
            background-color: #fff;
            border: 1px solid #e0e0e0;
            border-radius: 8px;
            margin-bottom: 16px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.08);
        }
        .card-title-box {
            background-color: #f8f9fa;
            padding: 12px 16px;
            border-radius: 8px 8px 0 0;
            border-bottom: 1px solid #e0e0e0;
        }
        .card-title {
            color: #333;
            font-weight: 600;
            font-size: 1rem;
            margin: 0;
        }
        .card-body {
            padding: 16px;
        }
        .stat-card {
            text-align: center;
            padding: 20px;
            background-color: #fff;
            border: 1px solid #e0e0e0;
            border-radius: 8px;
            margin-bottom: 16px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.08);
        }
        .stat-value {
            font-size: 1.8rem;
            font-weight: 700;
            margin-bottom: 4px;
        }
        .stat-desc {
            font-size: 0.85rem;
            color: #666;
        }
        .info-card {
            background-color: #f8f9fa;
            border-left: 4px solid #5bc0de;
            padding: 12px 16px;
            margin-bottom: 12px;
            border-radius: 0 8px 8px 0;
        }
        .info-card.warning {
            border-left-color: #f0ad4e;
            background-color: #fff8e6;
        }
        .info-card.danger {
            border-left-color: #d9534f;
            background-color: #fef2f2;
        }
        .info-card-title {
            font-weight: 600;
            margin-bottom: 4px;
            color: #333;
        }
        .info-card-desc {
            font-size: 0.85rem;
            color: #666;
        }
        .tag {
            display: inline-block;
            padding: 2px 8px;
            border-radius: 4px;
            font-size: 0.75rem;
            font-weight: 600;
            background-color: #4ECDC4;
            color: #fff;
        }
        .tag.expired, .tag.danger {
            background-color: #d9534f;
            color: white;
        }
        .tag.disabled, .tag.warning {
            background-color: #f0ad4e;
            color: #333;
        }
        table {
            width: 100%;
            border-collapse: collapse;
        }
        th {
            background-color: #f8f9fa;
            padding: 10px 12px;
            text-align: left;
            font-weight: 600;
            font-size: 0.85rem;
            color: #333;
            border-bottom: 2px solid #e0e0e0;
        }
        td {
            padding: 10px 12px;
            border-bottom: 1px solid #e9ecef;
            font-size: 0.85rem;
        }
        tr:hover {
            background-color: #f8f9fa;
        }
        /* Charts.css customization */
        .charts-css.bar {
            --color: #337ab7;
            height: 200px;
            max-width: 100%;
        }
        .charts-css tbody tr {
            background-color: transparent;
        }
        .charts-css tbody tr:hover {
            background-color: transparent;
        }
        .charts-css td {
            border: none;
            padding: 0;
        }
        .charts-css th {
            background-color: transparent;
            padding: 4px 8px;
            font-size: 0.75rem;
            color: #666;
        }
        .progress {
            background-color: #e9ecef;
            border-radius: 4px;
            height: 8px;
        }
        .progress-bar {
            border-radius: 4px;
        }
        a {
            color: #337ab7;
        }
        a:hover {
            color: #23527c;
        }
        .flex-grow-1 {
            flex-grow: 1;
        }
        .d-flex {
            display: flex;
        }
    </style>
</head>
<body>
    <div class="container-fluid">
        $Content
    </div>
    <!-- Bootstrap JS -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
"@
}

function New-HtmlCard {
    <#
    .SYNOPSIS
        Base card template - other card functions should use this.
    #>
    param (
        [string]$Title,
        [string]$Icon = "",
        [string]$Body,
        [string]$BodyStyle = "",
        [string]$CardStyle = ""
    )

    $iconHtml = if ($Icon) { "<i class=`"$Icon`"></i>&nbsp;&nbsp;" } else { "" }
    $bodyStyleAttr = if ($BodyStyle) { " style=`"$BodyStyle`"" } else { "" }
    $cardStyleAttr = if ($CardStyle) { " style=`"$CardStyle`"" } else { "" }

    @"
<div class="card flex-grow-1"$cardStyleAttr>
  <div class="card-title-box">
    <div class="card-title">$iconHtml$Title</div>
  </div>
  <div class="card-body"$bodyStyleAttr>$Body</div>
</div>
"@
}

function New-HtmlStatCard {
    param (
        [string]$Value,
        [string]$Description,
        [string]$Color = "",
        [string]$Icon = ""
    )

    if (-not $Color) { $Color = Get-ThemeColor -Severity "Primary" }
    $iconHtml = if ($Icon) { "<i class=`"$Icon`" style=`"margin-right: 8px;`"></i>" } else { "" }

    @"
<div class="stat-card">
  <div class="stat-value" style="color: $Color;">$iconHtml$Value</div>
  <div class="stat-desc">$Description</div>
</div>
"@
}

function New-HtmlInfoCard {
    param (
        [string]$Title,
        [string]$Description,
        [ValidateSet("Info", "Warning", "Danger", "Success")]
        [string]$Type = "Info"
    )

    $style = Get-SeverityStyle -Severity $Type
    $classExtra = if ($Type -eq "Info") { "" } else { " $($Type.ToLower())" }

    @"
<div class="info-card$classExtra">
  <i class="info-icon $($style.Icon)"></i>
  <div class="info-text">
    <div class="info-title">$Title</div>
    <div class="info-description">$Description</div>
  </div>
</div>
"@
}

function New-HtmlTag {
    param (
        [string]$Text,
        [ValidateSet("", "disabled", "expired")]
        [string]$Type = ""
    )
    $classExtra = if ($Type) { " $Type" } else { "" }
    "<div class=`"tag$classExtra`">$Text</div>"
}

function New-HtmlBarChart {
    param (
        [array]$Items,
        [string]$Title = "Top Items"
    )

    if ($null -eq $Items -or $Items.Count -eq 0) { return "" }

    # Find max value (can't use Measure-Object with hashtables)
    $maxValue = 0
    foreach ($item in $Items) {
        if ($item.Value -gt $maxValue) { $maxValue = $item.Value }
    }
    if ($maxValue -eq 0) { $maxValue = 1 }

    $maxLabel = $script:Config.Display.MaxLabelLength

    $rows = foreach ($item in $Items) {
        $percentage = [math]::Round(($item.Value / $maxValue), 4)
        $sizeText = Format-ByteSize -Bytes $item.Value
        $fullLabel = "$($item.Label)"
        $label = if ($fullLabel.Length -gt $maxLabel) { $fullLabel.Substring(0, $maxLabel - 2) + ".." } else { $fullLabel }
        @"
        <tr>
          <th scope="row" title="$fullLabel" style="font-size: 0.85em;">$label</th>
          <td style="--size: $percentage;"><span class="data">$sizeText</span></td>
        </tr>
"@
    }

    $icon = Get-ThemeIcon -IconName "Chart"
    $body = @"
    <table class="charts-css bar show-labels show-data-on-hover" style="height: 180px; width: 100%; --labels-size: 100px;">
      <tbody>
$($rows -join "`n")
      </tbody>
    </table>
"@

    New-HtmlCard -Title $Title -Icon $icon -Body $body -BodyStyle "padding: 8px;"
}

function New-HtmlLineChart {
    param (
        [array]$Segments,
        [long]$Total
    )

    if ($Total -eq 0) { $Total = 1 }

    $bars = foreach ($seg in $Segments) {
        $width = [math]::Round(($seg.Value / $Total) * 100, 2)
        "<div style=`"width: $width%; background-color: $($seg.Color);`"></div>"
    }

    $legendItems = foreach ($seg in $Segments) {
        $sizeText = Format-ByteSize -Bytes $seg.Value
        "<li><span class=`"chart-key`" style=`"background-color: $($seg.Color);`"></span><span>$($seg.Label) ($sizeText)</span></li>"
    }

    @"
<div class="p-3 linechart">
  $($bars -join "`n  ")
</div>
<ul class="unstyled p-3" style="display: flex; justify-content: space-between; flex-wrap: wrap;">
  $($legendItems -join "`n  ")
</ul>
"@
}

function New-HtmlTable {
    param (
        [array]$Items,
        [string]$Title = "Results",
        [string]$Icon = ""
    )

    if (-not $Icon) { $Icon = Get-ThemeIcon -IconName "Folder" }
    $folderIcon = Get-ThemeIcon -IconName "Folder"
    $fileIcon = Get-ThemeIcon -IconName "File"
    $warningColor = Get-ThemeColor -Severity "Warning"
    $infoColor = Get-ThemeColor -Severity "Info"

    $rows = foreach ($item in $Items) {
        $rowClass = Get-SizeCategory -SizeBytes $item.SizeBytes
        $typeIcon = if ($item.IsDirectory) { "<i class=`"$folderIcon`" style=`"color: $warningColor;`"></i>" } else { "<i class=`"$fileIcon`" style=`"color: $infoColor;`"></i>" }
        $lastMod = if ($item.LastModified) { $item.LastModified } else { "" }
        @"
    <tr class="$rowClass">
      <td>$typeIcon $($item.Path)</td>
      <td style="text-align: right; white-space: nowrap;">$($item.Size)</td>
      <td style="text-align: right; white-space: nowrap; color: #666;">$lastMod</td>
    </tr>
"@
    }

    $body = @"
    <table style="width: 100%;">
      <thead>
        <tr>
          <th>Path</th>
          <th style="text-align: right;">Size</th>
          <th style="text-align: right;">Modified</th>
        </tr>
      </thead>
      <tbody>
$($rows -join "`n")
      </tbody>
    </table>
"@

    New-HtmlCard -Title $Title -Icon $Icon -Body $body -BodyStyle "padding: 0;" -CardStyle "margin-bottom: 16px;"
}

function New-HtmlFileTypeTable {
    param ([array]$FileTypes)

    $colors = @("#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7", "#DDA0DD", "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E9", "#F8B500", "#00CED1", "#FF7F50", "#9370DB", "#20B2AA")

    $rows = for ($i = 0; $i -lt $FileTypes.Count; $i++) {
        $ft = $FileTypes[$i]
        $color = $colors[$i % $colors.Count]
        $sizeText = Format-ByteSize -Bytes $ft.TotalSize
        @"
    <tr>
      <td><span style="display: inline-block; width: 12px; height: 12px; background-color: $color; border-radius: 2px; margin-right: 8px;"></span>$($ft.Extension)</td>
      <td style="text-align: right;">$($ft.FileCount.ToString("N0"))</td>
      <td style="text-align: right;">$sizeText</td>
    </tr>
"@
    }

    $icon = Get-ThemeIcon -IconName "FileAlt"
    $body = @"
    <table style="width: 100%;">
      <thead>
        <tr>
          <th>Extension</th>
          <th style="text-align: right;">Count</th>
          <th style="text-align: right;">Total Size</th>
        </tr>
      </thead>
      <tbody>
$($rows -join "`n")
      </tbody>
    </table>
"@

    New-HtmlCard -Title "File Types by Size" -Icon $icon -Body $body -BodyStyle "padding: 0;" -CardStyle "margin-bottom: 16px;"
}

function New-HtmlCleanupSuggestions {
    param (
        [array]$Suggestions,
        [switch]$Compact
    )

    if ($null -eq $Suggestions -or $Suggestions.Count -eq 0) { return "" }

    $broomIcon = Get-ThemeIcon -IconName "Broom"

    if ($Compact) {
        $items = foreach ($sug in $Suggestions) {
            $sizeText = Format-ByteSize -Bytes $sug.Size
            $catInfo = Get-CleanupCategoryInfo -CategoryName $sug.Category
            $category = $script:CleanupCategories | Where-Object { $_.Name -eq $sug.Category }
            $displayName = if ($category) { $category.DisplayName } else { $sug.Path }

            "<li style=`"margin-bottom: 8px;`"><i class=`"$($catInfo.Icon)`" style=`"color: $($catInfo.Color); margin-right: 8px;`"></i><strong>$displayName</strong><br><span style=`"font-size: 0.9em; color: #666;`">$sizeText</span></li>"
        }

        $body = @"
    <ul style="list-style: none; padding: 0; margin: 0;">
      $($items -join "`n      ")
    </ul>
"@
        New-HtmlCard -Title "Cleanup" -Icon $broomIcon -Body $body -BodyStyle "padding: 12px;"
    }
    else {
        $cards = foreach ($sug in $Suggestions) {
            $sizeText = Format-ByteSize -Bytes $sug.Size
            $category = $script:CleanupCategories | Where-Object { $_.Name -eq $sug.Category }
            $displayName = if ($category) { $category.DisplayName } else { $sug.Path }
            $description = if ($category) { $category.Description } else { $sug.Description }
            $severity = if ($category) { $category.Severity } else { "Info" }

            New-HtmlInfoCard -Title "$displayName`: $sizeText" -Description $description -Type $severity
        }

        $body = $cards -join "`n    "
        New-HtmlCard -Title "Cleanup Suggestions" -Icon $broomIcon -Body $body -CardStyle "margin-bottom: 16px;"
    }
}

function New-HtmlDuplicatesTable {
    param (
        [array]$DuplicateGroups,
        [long]$TotalWasted
    )

    if ($null -eq $DuplicateGroups -or $DuplicateGroups.Count -eq 0) { return "" }

    $totalWastedText = Format-ByteSize -Bytes $TotalWasted
    $cfg = $script:Config.Display
    $maxGroups = $cfg.MaxDuplicateGroups
    $maxPaths = $cfg.MaxPathsPerGroup
    $maxPathLen = $cfg.MaxPathLength
    $copyIcon = Get-ThemeIcon -IconName "Copy"

    $rows = foreach ($group in $DuplicateGroups | Select-Object -First $maxGroups) {
        $sizeText = Format-ByteSize -Bytes $group.FileSize
        $wastedText = Format-ByteSize -Bytes $group.WastedSpace
        $fileCount = $group.Files.Count
        $filesToShow = $group.Files | Select-Object -First $maxPaths
        $remaining = $group.Files.Count - $maxPaths

        $fileName = Split-Path $group.Files[0] -Leaf

        $pathList = ($filesToShow | ForEach-Object {
            $parentPath = Split-Path $_ -Parent
            if ($parentPath.Length -gt $maxPathLen) { "..." + $parentPath.Substring($parentPath.Length - ($maxPathLen - 3)) } else { $parentPath }
        }) -join "<br>"

        if ($remaining -gt 0) {
            $mutedColor = Get-ThemeColor -Severity "Muted"
            $pathList += "<br><span style=`"color: $mutedColor;`">+$remaining more</span>"
        }

        $severity = Get-WastedSpaceSeverity -WastedBytes $group.WastedSpace
        $rowClass = $severity.ToLower()
        $borderColor = Get-ThemeColor -Severity $severity

        @"
    <tr class="$rowClass" style="border-left: 3px solid $borderColor;">
      <td style="padding: 1px 3px; font-size: 0.7em; white-space: nowrap; vertical-align: top;"><strong>$fileName</strong><br><span style="color: #888;">$fileCount &times; $sizeText</span></td>
      <td style="padding: 1px 3px; font-size: 0.65em; color: #666; line-height: 1.0;">$pathList</td>
      <td style="padding: 1px 3px; font-size: 0.7em; text-align: right; vertical-align: top;">$wastedText</td>
    </tr>
"@
    }

    @"
<h4 style="margin: 16px 0 8px 0;"><i class="$copyIcon"></i> Duplicate Files <span style="font-weight: normal; font-size: 0.85em; color: #666;">(Wasted: $totalWastedText)</span></h4>
<table style="width: 100%; border-collapse: collapse; border-spacing: 0;">
  <thead>
    <tr>
      <th style="padding: 1px 3px; font-size: 0.7em; text-align: left;">File</th>
      <th style="padding: 1px 3px; font-size: 0.7em; text-align: left;">Locations</th>
      <th style="padding: 1px 3px; font-size: 0.7em; text-align: right;">Wasted</th>
    </tr>
  </thead>
  <tbody>
$($rows -join "`n")
  </tbody>
</table>
"@
}

#endregion

#region Main Functions

function Get-FolderSizes {
    param (
        [Parameter(Mandatory = $false)][string]$DriveLetter,
        [int]$MaxDepth = 5,
        [int]$Top = 40,
        [Switch]$FolderSize,
        [Switch]$FileSize,
        [Switch]$VerboseOutput,
        [Switch]$AllDrives,
        [string[]]$ExcludeDrives,
        [Switch]$FindDuplicates,
        [long]$MinDuplicateSize = 0
    )

    # Use config default if not specified
    if ($MinDuplicateSize -eq 0) {
        $MinDuplicateSize = $script:Config.Thresholds.DuplicateMin
    }

    # Validate parameters
    Test-ScanParameters -DriveLetter $DriveLetter -MaxDepth $MaxDepth -Top $Top -MinDuplicateSize $MinDuplicateSize -AllDrives:$AllDrives

    if (-not $AllDrives -and -not $DriveLetter) {
        throw "You must specify either -DriveLetter or -AllDrives."
    }

    # Clear error log for new scan
    Clear-ErrorLog

    $drivesToProcess = if ($AllDrives) {
        $allFixed = (Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }).DeviceID
        if ($ExcludeDrives.Count -gt 0) {
            $excludeNormalized = $ExcludeDrives | ForEach-Object { $_.TrimEnd(':').ToUpper() + ':' }
            $allFixed | Where-Object { $_ -notin $excludeNormalized }
        } else {
            $allFixed
        }
    } else {
        @("$DriveLetter`:")
    }

    # Prepare category patterns for C#
    $categoryPatterns = $script:CleanupCategories | ForEach-Object { ,$_.Patterns }
    $categoryNames = $script:CleanupCategories | ForEach-Object { $_.Name }

    $allResults = [PSCustomObject]@{
        Items = [System.Collections.Generic.List[object]]::new()
        FileTypes = [System.Collections.Generic.List[object]]::new()
        CleanupSuggestions = [System.Collections.Generic.List[object]]::new()
        Duplicates = [System.Collections.Generic.List[object]]::new()
        DriveInfo = [System.Collections.Generic.List[object]]::new()
        TotalDuplicateWasted = 0
        TotalFiles = 0
        TotalFolders = 0
        TotalErrorCount = 0
    }

    foreach ($drive in $drivesToProcess) {
        if ($VerboseOutput) { Write-Output "Processing drive $drive" }
        $driveLetterOnly = $drive.TrimEnd(':')
        $includeFiles = $FileSize -or (-not $FolderSize -and -not $FileSize)

        try {
            $scanResult = [MftTreeSizeV8.MftScanner]::ScanWithAnalysis(
                $driveLetterOnly,
                $MaxDepth,
                $Top,
                $includeFiles,
                [bool]$VerboseOutput,
                [bool]$FindDuplicates,
                $MinDuplicateSize,
                $script:Config.Thresholds.LargeFile,
                $script:Config.Thresholds.CleanupMin,
                $categoryPatterns,
                $categoryNames
            )
        }
        catch {
            Add-ScanError -Path $drive -Category "io" -Message $_.Exception.Message
            Write-Warning "Failed to scan drive $drive`: $_"
            continue
        }

        # Add drive info
        $allResults.DriveInfo.Add([PSCustomObject]@{
            Drive = $drive
            TotalSize = $scanResult.TotalDriveSize
            UsedSpace = $scanResult.TotalUsedSpace
            FreeSpace = $scanResult.TotalFreeSpace
            UsedPercent = [math]::Round(($scanResult.TotalUsedSpace / $scanResult.TotalDriveSize) * 100, 1)
        })

        # Aggregate totals
        $allResults.TotalFiles += $scanResult.TotalFiles
        $allResults.TotalFolders += $scanResult.TotalFolders
        $allResults.TotalErrorCount += $scanResult.ErrorCount

        # Add items
        foreach ($item in $scanResult.Items) {
            $minValidDate = [DateTime]::new(1980, 1, 1)
            $lastMod = if ($item.LastModified -gt $minValidDate) { $item.LastModified.ToString("yyyy-MM-dd") } else { "" }
            $allResults.Items.Add([PSCustomObject]@{
                Drive = $drive
                Path = $item.Path
                Size = Format-ByteSize -Bytes $item.Size
                SizeBytes = $item.Size
                IsDirectory = $item.IsDirectory
                LastModified = $lastMod
            })
        }

        # Add file types
        foreach ($ft in $scanResult.FileTypes) {
            $allResults.FileTypes.Add([PSCustomObject]@{
                Drive = $drive
                Extension = $ft.Extension
                TotalSize = $ft.TotalSize
                FileCount = $ft.FileCount
            })
        }

        # Add cleanup suggestions
        foreach ($sug in $scanResult.CleanupSuggestions) {
            $allResults.CleanupSuggestions.Add([PSCustomObject]@{
                Drive = $drive
                Path = $sug.Path
                Category = $sug.Category
                Size = $sug.Size
                Description = $sug.Description
            })
        }

        # Add duplicates
        if ($FindDuplicates -and $scanResult.Duplicates -and $scanResult.Duplicates.Groups) {
            foreach ($group in $scanResult.Duplicates.Groups) {
                $allResults.Duplicates.Add([PSCustomObject]@{
                    Drive = $drive
                    Hash = $group.Hash
                    FileSize = $group.FileSize
                    Files = $group.Files
                    WastedSpace = $group.WastedSpace
                })
            }
            $allResults.TotalDuplicateWasted += $scanResult.Duplicates.TotalWastedSpace
        }
    }

    # Filter items
    if ($FolderSize -and -not $FileSize) {
        $allResults.Items = $allResults.Items | Where-Object { $_.IsDirectory }
    }
    elseif ($FileSize -and -not $FolderSize) {
        $allResults.Items = $allResults.Items | Where-Object { -not $_.IsDirectory }
    }

    # Sort and limit
    $allResults.Items = $allResults.Items | Sort-Object -Property SizeBytes -Descending | Select-Object -First $Top
    $allResults.Duplicates = $allResults.Duplicates | Sort-Object -Property WastedSpace -Descending

    return $allResults
}

function ConvertTo-NinjaOneHtml {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$ScanResults
    )

    $html = [System.Text.StringBuilder]::new()
    $cfg = $script:Config

    # === TOTAL SUMMARY STAT CARDS ===
    $driveCount = $ScanResults.DriveInfo.Count
    $totalScanned = "{0:N0}" -f ($ScanResults.TotalFiles + $ScanResults.TotalFolders)
    $duplicateWastedText = if ($ScanResults.TotalDuplicateWasted -gt 0) { Format-ByteSize -Bytes $ScanResults.TotalDuplicateWasted } else { "0 B" }
    $cleanupPotential = ($ScanResults.CleanupSuggestions | Measure-Object -Property Size -Sum).Sum
    $cleanupPotentialText = if ($cleanupPotential -gt 0) { Format-ByteSize -Bytes $cleanupPotential } else { "0 B" }

    $primaryColor = Get-ThemeColor -Severity "Primary"
    $warningColor = Get-ThemeColor -Severity "Warning"
    $infoColor = Get-ThemeColor -Severity "Info"
    $driveIcon = Get-ThemeIcon -IconName "Drive"
    $searchIcon = Get-ThemeIcon -IconName "Search"
    $copyIcon = Get-ThemeIcon -IconName "Copy"
    $broomIcon = Get-ThemeIcon -IconName "Broom"

    [void]$html.AppendLine('<div class="row g-3" style="margin-bottom: 16px;">')
    [void]$html.AppendLine('<div class="col-xl-3 col-lg-3 col-md-6 col-sm-6">')
    [void]$html.AppendLine((New-HtmlStatCard -Value $driveCount -Description "Drives Scanned" -Color $primaryColor -Icon $driveIcon))
    [void]$html.AppendLine('</div>')
    [void]$html.AppendLine('<div class="col-xl-3 col-lg-3 col-md-6 col-sm-6">')
    [void]$html.AppendLine((New-HtmlStatCard -Value $totalScanned -Description "Items (All Drives)" -Color $primaryColor -Icon $searchIcon))
    [void]$html.AppendLine('</div>')
    [void]$html.AppendLine('<div class="col-xl-3 col-lg-3 col-md-6 col-sm-6">')
    [void]$html.AppendLine((New-HtmlStatCard -Value $duplicateWastedText -Description "Duplicates (All Drives)" -Color $warningColor -Icon $copyIcon))
    [void]$html.AppendLine('</div>')
    [void]$html.AppendLine('<div class="col-xl-3 col-lg-3 col-md-6 col-sm-6">')
    [void]$html.AppendLine((New-HtmlStatCard -Value $cleanupPotentialText -Description "Cleanup Potential" -Color $infoColor -Icon $broomIcon))
    [void]$html.AppendLine('</div>')
    [void]$html.AppendLine('</div>')

    # === ERROR WARNING ===
    if ($ScanResults.TotalErrorCount -gt $cfg.Thresholds.ErrorWarning) {
        [void]$html.AppendLine((New-HtmlInfoCard -Title "Access Errors" -Description "$($ScanResults.TotalErrorCount) files could not be read (access denied or in use)" -Type "Warning"))
    }

    # === PER-DRIVE SECTIONS ===
    foreach ($drive in $ScanResults.DriveInfo) {
        $usedText = Format-ByteSize -Bytes $drive.UsedSpace
        $freeText = Format-ByteSize -Bytes $drive.FreeSpace
        $healthTag = Get-DiskHealthTag -UsedPercent $drive.UsedPercent
        $usedColor = Get-DiskUsedColor -UsedPercent $drive.UsedPercent
        $successColor = Get-ThemeColor -Severity "Success"
        $freeColor = Get-ThemeColor -Severity "Free"

        $driveCleanup = @($ScanResults.CleanupSuggestions | Where-Object { $_.Drive -eq $drive.Drive })
        $driveFolders = @($ScanResults.Items | Where-Object { $_.Drive -eq $drive.Drive -and $_.IsDirectory } | Select-Object -First $cfg.Display.MaxTopFolders)
        $driveFileTypes = @($ScanResults.FileTypes | Where-Object { $_.Drive -eq $drive.Drive } | Select-Object -First $cfg.Display.MaxFileTypes)

        # Row 1: Stat cards
        [void]$html.AppendLine('<div class="row g-3" style="margin-bottom: 8px;">')

        [void]$html.AppendLine('<div class="col-xl-3 col-lg-3 col-md-6 col-sm-6">')
        [void]$html.AppendLine((New-HtmlStatCard -Value "$($drive.Drive)" -Description "Drive" -Color $primaryColor -Icon $driveIcon))
        [void]$html.AppendLine('</div>')

        [void]$html.AppendLine('<div class="col-xl-3 col-lg-3 col-md-6 col-sm-6">')
        [void]$html.AppendLine((New-HtmlStatCard -Value $usedText -Description "Used ($($drive.UsedPercent)%)" -Color $usedColor))
        [void]$html.AppendLine('</div>')

        [void]$html.AppendLine('<div class="col-xl-3 col-lg-3 col-md-6 col-sm-6">')
        [void]$html.AppendLine((New-HtmlStatCard -Value $freeText -Description "Free" -Color $successColor))
        [void]$html.AppendLine('</div>')

        [void]$html.AppendLine('<div class="col-xl-3 col-lg-3 col-md-6 col-sm-6">')
        [void]$html.AppendLine("<div class=`"stat-card`"><div class=`"stat-value`">$(New-HtmlTag -Text $healthTag.Text -Type $healthTag.Class)</div><div class=`"stat-desc`">Status</div></div>")
        [void]$html.AppendLine('</div>')

        # Row 2: Line chart
        [void]$html.AppendLine('<div class="col-12">')
        $segments = @(
            @{ Label = "Used"; Value = $drive.UsedSpace; Color = $usedColor }
            @{ Label = "Free"; Value = $drive.FreeSpace; Color = $freeColor }
        )
        [void]$html.AppendLine((New-HtmlLineChart -Segments $segments -Total $drive.TotalSize))
        [void]$html.AppendLine('</div>')

        [void]$html.AppendLine('</div>')

        # Row 3: Three-column layout
        [void]$html.AppendLine('<div class="row g-3" style="margin-bottom: 16px;">')

        [void]$html.AppendLine('<div class="col-xl-4 col-lg-4 col-md-12 d-flex">')
        if ($driveCleanup.Count -gt 0) {
            [void]$html.AppendLine((New-HtmlCleanupSuggestions -Suggestions $driveCleanup -Compact))
        } else {
            $checkIcon = Get-ThemeIcon -IconName "CheckCircle"
            [void]$html.AppendLine("<div class=`"card flex-grow-1`"><div class=`"card-title-box`"><div class=`"card-title`"><i class=`"$checkIcon`" style=`"color: $successColor;`"></i>&nbsp;&nbsp;No Cleanup Needed</div></div><div class=`"card-body`"><p style=`"color: #666;`">No significant cleanup opportunities found.</p></div></div>")
        }
        [void]$html.AppendLine('</div>')

        [void]$html.AppendLine('<div class="col-xl-4 col-lg-4 col-md-12 d-flex">')
        if ($driveFolders.Count -gt 0) {
            $chartItems = $driveFolders | ForEach-Object {
                $label = Split-Path $_.Path -Leaf
                if ([string]::IsNullOrEmpty($label)) { $label = $_.Path }
                @{ Label = $label; Value = $_.SizeBytes }
            }
            [void]$html.AppendLine((New-HtmlBarChart -Items $chartItems -Title "Top Folders"))
        }
        [void]$html.AppendLine('</div>')

        [void]$html.AppendLine('<div class="col-xl-4 col-lg-4 col-md-12 d-flex">')
        if ($driveFileTypes.Count -gt 0) {
            [void]$html.AppendLine((New-HtmlFileTypeTable -FileTypes $driveFileTypes))
        }
        [void]$html.AppendLine('</div>')

        [void]$html.AppendLine('</div>')
    }

    # === DUPLICATES TABLE ===
    if ($ScanResults.Duplicates.Count -gt 0) {
        [void]$html.AppendLine((New-HtmlDuplicatesTable -DuplicateGroups $ScanResults.Duplicates -TotalWasted $ScanResults.TotalDuplicateWasted))
    }

    # === FULL RESULTS TABLE ===
    $listIcon = Get-ThemeIcon -IconName "List"
    [void]$html.AppendLine((New-HtmlTable -Items $ScanResults.Items -Title "All Results by Size" -Icon $listIcon))

    # === FOOTER ===
    $scanTime = Get-Date -Format "yyyy-MM-dd HH:mm"
    $mutedColor = Get-ThemeColor -Severity "Muted"
    [void]$html.AppendLine("<p style=`"font-size: 0.7em; color: $mutedColor; text-align: right; margin-top: 16px;`">TreeSize v$($cfg.Version) | Scanned: $scanTime</p>")

    return $html.ToString()
}

#endregion

# === MAIN EXECUTION ===
if (-not $TestMode) {
    #With Duplication Detection
    $results = Get-FolderSizes -AllDrives -MaxDepth 5 -Top $script:Config.Display.MaxResults -FolderSize -FileSize -VerboseOutput -FindDuplicates -MinDuplicateSize $script:Config.Thresholds.DuplicateMin
    $html = ConvertTo-NinjaOneHtml -ScanResults $results

    #Without Duplication Detection
    #$results = Get-FolderSizes -AllDrives -MaxDepth 5 -Top $script:Config.Display.MaxResults -FolderSize -FileSize -VerboseOutput
    #$html = ConvertTo-NinjaOneHtml -ScanResults $results

    # Output to NinjaOne
    $html | Ninja-Property-Set-Piped treesize

    # For testing, save to file with full HTML wrapper (includes CSS/JS dependencies)
    #$wrappedHtml = New-HtmlWrapper -Content $html -Title "TreeSize Report - $(Get-Date -Format 'yyyy-MM-dd')"
    #$outputPath = Join-Path $PSScriptRoot "treesize-v9-output.html"
    #$wrappedHtml | Out-File $outputPath -Encoding UTF8
    #Write-Host "HTML output saved to $outputPath (with full HTML wrapper for local viewing)"
}
