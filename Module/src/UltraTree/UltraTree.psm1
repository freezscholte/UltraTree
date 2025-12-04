# UltraTree Module Loader
# This psm1 is for local testing and development use only

# dot source the parent import for local development variables
. $PSScriptRoot\Imports.ps1

# discover all ps1 file(s) in Classes, Private, and Public paths
$itemSplat = @{
    Filter      = '*.ps1'
    Recurse     = $true
    ErrorAction = 'Stop'
}

try {
    $classes = @(Get-ChildItem -Path "$PSScriptRoot\Classes" @itemSplat)
    $private = @(Get-ChildItem -Path "$PSScriptRoot\Private" @itemSplat)
    $public = @(Get-ChildItem -Path "$PSScriptRoot\Public" @itemSplat)
}
catch {
    Write-Error $_
    throw 'Unable to get file information from Classes/Private/Public src.'
}

# Load order:
# 1. Classes first (C# types must be loaded before anything else)
# 2. Configuration.ps1 (sets up $script:Config and other module-level variables)
# 3. Remaining Private functions
# 4. Public functions

# Load Classes (C# type definitions)
foreach ($file in $classes) {
    try {
        . $file.FullName
    }
    catch {
        throw ('Unable to dot source {0}' -f $file.FullName)
    }
}

# Load Configuration first from Private (contains $script:Config, $script:CleanupCategories, $script:ErrorLog)
$configFile = $private | Where-Object { $_.Name -eq 'Configuration.ps1' }
if ($configFile) {
    try {
        . $configFile.FullName
    }
    catch {
        throw ('Unable to dot source Configuration.ps1: {0}' -f $_)
    }
}

# Load remaining Private functions (excluding Configuration.ps1)
foreach ($file in ($private | Where-Object { $_.Name -ne 'Configuration.ps1' })) {
    try {
        . $file.FullName
    }
    catch {
        throw ('Unable to dot source {0}' -f $file.FullName)
    }
}

# Load Public functions
foreach ($file in $public) {
    try {
        . $file.FullName
    }
    catch {
        throw ('Unable to dot source {0}' -f $file.FullName)
    }
}

# export all public functions
Export-ModuleMember -Function $public.Basename
