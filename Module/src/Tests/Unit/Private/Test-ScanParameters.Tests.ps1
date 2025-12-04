BeforeAll {
    Set-Location -Path $PSScriptRoot
    $ModuleName = 'UltraTree'
    $PathToManifest = [System.IO.Path]::Combine('..', '..', '..', $ModuleName, "$ModuleName.psd1")
    Get-Module $ModuleName -ErrorAction SilentlyContinue | Remove-Module -Force
    Import-Module $PathToManifest -Force
}

Describe 'Test-ScanParameters' -Tag Unit {
    Context 'MaxDepth validation' {
        It 'Throws on negative MaxDepth' {
            InModuleScope UltraTree {
                { Test-ScanParameters -MaxDepth -1 -Top 10 -MinDuplicateSize 1MB } | Should -Throw "*MaxDepth must be at least 1*"
            }
        }

        It 'Throws on zero MaxDepth' {
            InModuleScope UltraTree {
                { Test-ScanParameters -MaxDepth 0 -Top 10 -MinDuplicateSize 1MB } | Should -Throw "*MaxDepth must be at least 1*"
            }
        }

        It 'Throws on MaxDepth over 20' {
            InModuleScope UltraTree {
                { Test-ScanParameters -MaxDepth 25 -Top 10 -MinDuplicateSize 1MB } | Should -Throw "*MaxDepth cannot exceed 20*"
            }
        }

        It 'Accepts valid MaxDepth of 1' {
            InModuleScope UltraTree {
                { Test-ScanParameters -MaxDepth 1 -Top 10 -MinDuplicateSize 1MB } | Should -Not -Throw
            }
        }

        It 'Accepts valid MaxDepth of 20' {
            InModuleScope UltraTree {
                { Test-ScanParameters -MaxDepth 20 -Top 10 -MinDuplicateSize 1MB } | Should -Not -Throw
            }
        }
    }

    Context 'Top validation' {
        It 'Throws on zero Top' {
            InModuleScope UltraTree {
                { Test-ScanParameters -MaxDepth 5 -Top 0 -MinDuplicateSize 1MB } | Should -Throw "*Top must be at least 1*"
            }
        }

        It 'Throws on negative Top' {
            InModuleScope UltraTree {
                { Test-ScanParameters -MaxDepth 5 -Top -5 -MinDuplicateSize 1MB } | Should -Throw "*Top must be at least 1*"
            }
        }

        It 'Throws on Top over 1000' {
            InModuleScope UltraTree {
                { Test-ScanParameters -MaxDepth 5 -Top 1500 -MinDuplicateSize 1MB } | Should -Throw "*Top cannot exceed 1000*"
            }
        }

        It 'Accepts valid Top of 1' {
            InModuleScope UltraTree {
                { Test-ScanParameters -MaxDepth 5 -Top 1 -MinDuplicateSize 1MB } | Should -Not -Throw
            }
        }

        It 'Accepts valid Top of 1000' {
            InModuleScope UltraTree {
                { Test-ScanParameters -MaxDepth 5 -Top 1000 -MinDuplicateSize 1MB } | Should -Not -Throw
            }
        }
    }

    Context 'MinDuplicateSize validation' {
        It 'Throws on negative MinDuplicateSize' {
            InModuleScope UltraTree {
                { Test-ScanParameters -MaxDepth 5 -Top 10 -MinDuplicateSize -1 } | Should -Throw "*MinDuplicateSize cannot be negative*"
            }
        }

        It 'Accepts zero MinDuplicateSize' {
            InModuleScope UltraTree {
                { Test-ScanParameters -MaxDepth 5 -Top 10 -MinDuplicateSize 0 } | Should -Not -Throw
            }
        }
    }

    Context 'Valid parameter combinations' {
        It 'Passes with all valid parameters' {
            InModuleScope UltraTree {
                { Test-ScanParameters -MaxDepth 5 -Top 40 -MinDuplicateSize 10MB } | Should -Not -Throw
            }
        }
    }
}
