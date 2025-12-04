# Installation

## From PowerShell Gallery

The easiest way to install UltraTree:

```powershell
Install-Module -Name UltraTree -Scope CurrentUser
```

For system-wide installation (required for NinjaOne/SYSTEM account):

```powershell
# Run as Administrator
Install-Module -Name UltraTree -Scope AllUsers
```

## Manual Installation (System-Wide)

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

## Manual Installation (Current User Only)

For local development or testing:

```powershell
git clone https://github.com/freezscholte/UltraTree.git "$env:TEMP\UltraTree"
Copy-Item -Path "$env:TEMP\UltraTree\Module\src\UltraTree" -Destination "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\UltraTree" -Recurse -Force
Remove-Item -Path "$env:TEMP\UltraTree" -Recurse -Force
```

## Development / Direct Import

For development or one-time use, import directly without installing:

```powershell
git clone https://github.com/freezscholte/UltraTree.git
Import-Module ./UltraTree/Module/src/UltraTree -Force
```

## Verify Installation

After installation, verify the module is available:

```powershell
# Check module is loaded
Get-Module -Name UltraTree -ListAvailable

# List exported functions
Get-Command -Module UltraTree
```

Expected output:

```
CommandType     Name                        Version    Source
-----------     ----                        -------    ------
Function        ConvertTo-NinjaOneHtml      1.0.0      UltraTree
Function        Get-FolderSizes             1.0.0      UltraTree
```

## Updating

### From PowerShell Gallery

```powershell
Update-Module -Name UltraTree
```

### Manual Update

Remove the old version and reinstall:

```powershell
Remove-Item "$env:ProgramFiles\WindowsPowerShell\Modules\UltraTree" -Recurse -Force
# Then follow manual installation steps above
```

## Uninstalling

### From PowerShell Gallery

```powershell
Uninstall-Module -Name UltraTree
```

### Manual Uninstall

```powershell
Remove-Item "$env:ProgramFiles\WindowsPowerShell\Modules\UltraTree" -Recurse -Force
```
