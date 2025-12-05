# CLAUDE.md - Development Guide for UltraTree

This document describes the code quality standards, development workflow, and best practices for contributing to UltraTree.

## Project Overview

UltraTree is a PowerShell module for ultra-fast disk space analysis using NTFS MFT enumeration. It's designed for system administrators and MSPs, with HTML output optimized for NinjaOne RMM.

## Project Structure

```
UltraTree/
├── Module/
│   ├── src/
│   │   ├── UltraTree/              # Module source
│   │   │   ├── Public/             # Exported functions
│   │   │   ├── Private/            # Internal helper functions
│   │   │   ├── Classes/            # C# classes (MFT reader, xxHash64)
│   │   │   ├── UltraTree.psd1      # Module manifest
│   │   │   └── UltraTree.psm1      # Module loader
│   │   ├── Tests/                  # Pester tests
│   │   ├── UltraTree.build.ps1     # InvokeBuild build script
│   │   ├── PSScriptAnalyzerSettings.psd1
│   │   ├── Artifacts/              # Build output (gitignored)
│   │   └── Archive/                # Release zips (gitignored)
│   ├── docs/                       # MkDocs documentation
│   ├── mkdocs.yml                  # MkDocs configuration
│   └── actions_bootstrap.ps1       # CI dependency installer
├── .github/
│   └── workflows/
│       ├── wf_Windows.yml          # CI pipeline (test + build)
│       └── publish.yml             # PSGallery publish
└── CLAUDE.md                       # This file
```

## Development Workflow

### 1. Local Development

```powershell
# Import module for testing
Import-Module .\Module\src\UltraTree -Force

# Test your changes
Get-FolderSizes -DriveLetter C -MaxDepth 3 | ConvertTo-NinjaOneHtml | New-HtmlWrapper | Out-File test.html
```

### 2. Run Tests Locally

```powershell
cd Module/src

# Run full build (includes tests)
Invoke-Build -File .\UltraTree.build.ps1

# Run only tests
Invoke-Build -File .\UltraTree.build.ps1 -Task Test
```

### 3. Run PSScriptAnalyzer

```powershell
Invoke-ScriptAnalyzer -Path .\Module\src\UltraTree -Settings .\Module\src\PSScriptAnalyzerSettings.psd1 -Recurse
```

## Code Quality Standards

### PSScriptAnalyzer

All code must pass PSScriptAnalyzer with the project settings. The following rules are excluded:

- `PSUseConsistentIndentation` - Flexible indentation allowed
- `PSAlignAssignmentStatement` - Assignment alignment not enforced
- `PSPlaceCloseBrace` - Brace placement flexible
- `PSUseShouldProcessForStateChangingFunctions` - HTML functions only return strings
- `PSUseSingularNouns` - `Get-FolderSizes` is intentionally plural

### Function Standards

#### Public Functions (Exported)

Located in `Module/src/UltraTree/Public/`. Must include:

- Comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`)
- `[CmdletBinding()]` attribute
- Proper parameter validation where applicable
- Pipeline support where it makes sense (`[Parameter(ValueFromPipeline)]`)

Example:
```powershell
function Get-Example {
    <#
    .SYNOPSIS
        Brief description.
    .DESCRIPTION
        Detailed description.
    .PARAMETER Name
        Parameter description.
    .EXAMPLE
        Get-Example -Name "Test"
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        [string]$Name
    )

    process {
        # Implementation
    }
}
```

#### Private Functions (Internal)

Located in `Module/src/UltraTree/Private/`. Used for:

- Helper functions not exposed to users
- Configuration loading
- Internal utilities

### Naming Conventions

- **Functions**: Use approved PowerShell verbs (`Get-`, `Set-`, `New-`, `ConvertTo-`, etc.)
- **Variables**: PascalCase for parameters, camelCase for local variables
- **Files**: Match function name exactly (e.g., `Get-FolderSizes.ps1`)

### Module Manifest

When adding new public functions:

1. Create the function in `Public/` folder
2. Add to `FunctionsToExport` in `UltraTree.psd1`
3. The module loader (`UltraTree.psm1`) auto-loads all `.ps1` files

## Git Workflow

### Commit Messages

Follow conventional format:
```
<type>: <description>

<optional body>

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

Types:
- `Add` - New feature
- `Fix` - Bug fix
- `Update` - Enhancement to existing feature
- `Remove` - Removed feature
- `Refactor` - Code restructuring
- `Docs` - Documentation only
- `Test` - Test additions/changes

### Branch Strategy

- `main` - Production branch, protected
- Feature branches for development
- PRs required for main branch

### Files NOT to Commit

See `.gitignore`. Key exclusions:
- `Test.ps1`, `Test2.ps1` - Local test scripts
- `*.html` - Generated reports (except docs)
- `Module/src/Artifacts/` - Build output
- `Module/src/Archive/` - Release archives
- `Module/site/` - MkDocs build output

## Testing

### Pester Tests

Located in `Module/src/Tests/`. Run with:

```powershell
Invoke-Build -File .\Module\src\UltraTree.build.ps1 -Task Test
```

### Test Categories

- Unit tests for individual functions
- Integration tests for full workflows
- Module manifest validation

## CI/CD Pipeline

### GitHub Actions

**`wf_Windows.yml`** - Runs on every push/PR:
1. Installs dependencies (NuGet, PowerShellGet)
2. Runs bootstrap script
3. Executes `Invoke-Build` (tests + build)
4. Uploads test results and build artifacts

**`publish.yml`** - Manual trigger for PSGallery release

### Required Checks

Before merging:
- All Pester tests pass
- PSScriptAnalyzer passes
- Build completes successfully

## Documentation

### MkDocs

Documentation lives in `Module/docs/`. Preview locally:

```bash
cd Module
pip install mkdocs mkdocs-material
mkdocs serve
```

Open http://127.0.0.1:8000/

### README Updates

When adding features, update:
- `Module/README.md` - Main documentation
- `Module/docs/*.md` - Detailed docs if applicable
- Function help comments

## Key Design Decisions

1. **Pipeline Support**: All output functions support pipeline input for clean one-liners
2. **Separate Functions**: `Get-FolderSizes`, `ConvertTo-NinjaOneHtml`, `New-HtmlWrapper` are separate (Unix philosophy)
3. **NinjaOne Optimized**: HTML output designed for WYSIWYG fields (Bootstrap/Charts.css loaded externally)
4. **MFT Enumeration**: Uses embedded C# for 10-100x faster scanning than recursive directory walking
5. **xxHash64**: Fast duplicate detection with 3-stage verification (size → hash → full compare)

## Quick Reference

```powershell
# Import for development
Import-Module .\Module\src\UltraTree -Force

# Full pipeline test
Get-FolderSizes -AllDrives -FindDuplicates | ConvertTo-NinjaOneHtml | New-HtmlWrapper | Out-File test.html

# Run PSScriptAnalyzer
Invoke-ScriptAnalyzer -Path .\Module\src\UltraTree -Settings .\Module\src\PSScriptAnalyzerSettings.psd1 -Recurse

# Run tests
Invoke-Build -File .\Module\src\UltraTree.build.ps1 -Task Test

# Full build
Invoke-Build -File .\Module\src\UltraTree.build.ps1
```
