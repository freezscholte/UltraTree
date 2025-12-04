BeforeAll {
    Set-Location -Path $PSScriptRoot
    $ModuleName = 'UltraTree'
    $PathToManifest = [System.IO.Path]::Combine('..', '..', '..', $ModuleName, "$ModuleName.psd1")
    Get-Module $ModuleName -ErrorAction SilentlyContinue | Remove-Module -Force
    Import-Module $PathToManifest -Force
}

Describe 'Get-ThemeColor' -Tag Unit {
    Context 'Theme colors' {
        It 'Returns correct color for Danger' {
            InModuleScope UltraTree { Get-ThemeColor -Severity "Danger" | Should -Be "#d9534f" }
        }

        It 'Returns correct color for Warning' {
            InModuleScope UltraTree { Get-ThemeColor -Severity "Warning" | Should -Be "#f0ad4e" }
        }

        It 'Returns correct color for Info' {
            InModuleScope UltraTree { Get-ThemeColor -Severity "Info" | Should -Be "#5bc0de" }
        }

        It 'Returns correct color for Success' {
            InModuleScope UltraTree { Get-ThemeColor -Severity "Success" | Should -Be "#4ECDC4" }
        }

        It 'Returns correct color for Primary' {
            InModuleScope UltraTree { Get-ThemeColor -Severity "Primary" | Should -Be "#337ab7" }
        }

        It 'Returns correct color for Muted' {
            InModuleScope UltraTree { Get-ThemeColor -Severity "Muted" | Should -Be "#999999" }
        }

        It 'Returns correct color for Critical' {
            InModuleScope UltraTree { Get-ThemeColor -Severity "Critical" | Should -Be "#FF6B6B" }
        }

        It 'Returns correct color for Free' {
            InModuleScope UltraTree { Get-ThemeColor -Severity "Free" | Should -Be "#95a5a6" }
        }
    }
}
