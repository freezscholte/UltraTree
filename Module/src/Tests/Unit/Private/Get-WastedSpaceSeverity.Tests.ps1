BeforeAll {
    Set-Location -Path $PSScriptRoot
    $ModuleName = 'UltraTree'
    $PathToManifest = [System.IO.Path]::Combine('..', '..', '..', $ModuleName, "$ModuleName.psd1")
    Get-Module $ModuleName -ErrorAction SilentlyContinue | Remove-Module -Force
    Import-Module $PathToManifest -Force
}

Describe 'Get-WastedSpaceSeverity' -Tag Unit {
    Context 'Wasted space severity' {
        It 'Returns Danger for wasted space over 500MB' {
            InModuleScope UltraTree { Get-WastedSpaceSeverity -WastedBytes (600MB) | Should -Be "Danger" }
        }

        It 'Returns Warning for wasted space between 100MB and 500MB' {
            InModuleScope UltraTree { Get-WastedSpaceSeverity -WastedBytes (200MB) | Should -Be "Warning" }
        }

        It 'Returns Info for wasted space under 100MB' {
            InModuleScope UltraTree { Get-WastedSpaceSeverity -WastedBytes (50MB) | Should -Be "Info" }
        }
    }
}
