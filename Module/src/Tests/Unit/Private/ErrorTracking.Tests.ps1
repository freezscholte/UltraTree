BeforeAll {
    Set-Location -Path $PSScriptRoot
    $ModuleName = 'UltraTree'
    $PathToManifest = [System.IO.Path]::Combine('..', '..', '..', $ModuleName, "$ModuleName.psd1")
    Get-Module $ModuleName -ErrorAction SilentlyContinue | Remove-Module -Force
    Import-Module $PathToManifest -Force
}

Describe 'Error Tracking Functions' -Tag Unit {
    BeforeEach {
        InModuleScope UltraTree { Clear-ErrorLog }
    }

    Context 'Clear-ErrorLog' {
        It 'Starts with empty error log after clear' {
            InModuleScope UltraTree { $script:ErrorLog.Count | Should -Be 0 }
        }

        It 'Clears existing errors' {
            InModuleScope UltraTree {
                Add-ScanError -Path "C:\test" -Category "access" -Message "Test"
                $script:ErrorLog.Count | Should -Be 1
                Clear-ErrorLog
                $script:ErrorLog.Count | Should -Be 0
            }
        }
    }

    Context 'Add-ScanError' {
        It 'Adds errors to the log' {
            InModuleScope UltraTree {
                Add-ScanError -Path "C:\test" -Category "access" -Message "Access denied"
                $script:ErrorLog.Count | Should -Be 1
                $script:ErrorLog[0].Path | Should -Be "C:\test"
                $script:ErrorLog[0].Category | Should -Be "access"
                $script:ErrorLog[0].Message | Should -Be "Access denied"
            }
        }

        It 'Records timestamp' {
            InModuleScope UltraTree {
                Add-ScanError -Path "C:\test" -Category "io"
                $script:ErrorLog[0].Timestamp | Should -BeOfType [DateTime]
            }
        }

        It 'Accepts different categories' {
            InModuleScope UltraTree {
                Add-ScanError -Path "C:\test1" -Category "access"
                Add-ScanError -Path "C:\test2" -Category "io"
                Add-ScanError -Path "C:\test3" -Category "timeout"
                Add-ScanError -Path "C:\test4" -Category "unknown"
                $script:ErrorLog.Count | Should -Be 4
            }
        }
    }

    Context 'Get-ErrorSummary' {
        It 'Returns null when no errors' {
            InModuleScope UltraTree { Get-ErrorSummary | Should -BeNullOrEmpty }
        }

        It 'Returns summary with single error' {
            InModuleScope UltraTree {
                Add-ScanError -Path "C:\test" -Category "access" -Message "Test"
                $summary = Get-ErrorSummary
                $summary | Should -Match "1 error"
                $summary | Should -Match "access"
            }
        }

        It 'Returns grouped summary with multiple errors' {
            InModuleScope UltraTree {
                Add-ScanError -Path "C:\test1" -Category "access" -Message "Access denied"
                Add-ScanError -Path "C:\test2" -Category "io" -Message "IO error"
                Add-ScanError -Path "C:\test3" -Category "access" -Message "Another access error"

                $summary = Get-ErrorSummary
                $summary | Should -Match "3 errors"
                $summary | Should -Match "2 access"
                $summary | Should -Match "1 io"
            }
        }
    }
}
