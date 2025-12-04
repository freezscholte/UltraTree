BeforeAll {
    Set-Location -Path $PSScriptRoot
    $ModuleName = 'UltraTree'
    $PathToManifest = [System.IO.Path]::Combine('..', '..', '..', $ModuleName, "$ModuleName.psd1")
    Get-Module $ModuleName -ErrorAction SilentlyContinue | Remove-Module -Force
    Import-Module $PathToManifest -Force
}

Describe 'Get-CleanupCategoryInfo' -Tag Unit {
    Context 'Known categories' {
        It 'Returns correct info for recycleBin category' {
            InModuleScope UltraTree {
                $info = Get-CleanupCategoryInfo -CategoryName "recycleBin"
                $info.Icon | Should -Be "fas fa-trash"
                $info.Color | Should -Be "#f0ad4e"
            }
        }

        It 'Returns correct info for temp category' {
            InModuleScope UltraTree {
                $info = Get-CleanupCategoryInfo -CategoryName "temp"
                $info.Icon | Should -Be "fas fa-clock"
                $info.Color | Should -Be "#5bc0de"
            }
        }

        It 'Returns correct info for cache category' {
            InModuleScope UltraTree {
                $info = Get-CleanupCategoryInfo -CategoryName "cache"
                $info.Icon | Should -Be "fas fa-database"
                $info.Color | Should -Be "#5bc0de"
            }
        }

        It 'Returns correct info for nodeModules category' {
            InModuleScope UltraTree {
                $info = Get-CleanupCategoryInfo -CategoryName "nodeModules"
                $info.Icon | Should -Be "fas fa-code"
                $info.Color | Should -Be "#5bc0de"
            }
        }
    }

    Context 'Unknown category fallback' {
        It 'Returns fallback info for unknown category' {
            InModuleScope UltraTree {
                $info = Get-CleanupCategoryInfo -CategoryName "unknownCategory"
                $info.Icon | Should -Be "fas fa-folder"
                $info.Color | Should -Be "#5bc0de"
            }
        }
    }
}
