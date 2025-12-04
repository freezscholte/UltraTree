# UltraTree Monolith (Single-Script Version)

This folder contains the original single-file version of UltraTree.

## Files

| File | Description |
|------|-------------|
| `UltraTree.ps1` | Complete standalone script (~2500 lines) |
| `UltraTree.Tests.ps1` | Original Pester tests |
| `TECHNICAL.md` | Technical documentation |

## Usage

The monolith can be used without installation:

```powershell
# Dot-source and run
. .\UltraTree.ps1
$results = Get-FolderSizes -AllDrives -FindDuplicates
$html = ConvertTo-NinjaOneHtml -ScanResults $results
```

## Note

For production use, prefer the **PowerShell Module** version in `/Module` which provides:
- Proper module installation via `Install-Module`
- Better maintainability
- Automated testing and publishing

The monolith is kept for reference and for scenarios where a single portable script is needed.
