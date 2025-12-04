BeforeAll {
    Set-Location -Path $PSScriptRoot
    $ModuleName = 'UltraTree'
    $PathToManifest = [System.IO.Path]::Combine('..', '..', '..', $ModuleName, "$ModuleName.psd1")
    Get-Module $ModuleName -ErrorAction SilentlyContinue | Remove-Module -Force
    Import-Module $PathToManifest -Force
}

Describe 'Get-DiskHealthTag' -Tag Unit {
    Context 'Disk health status' {
        It 'Returns Critical for usage over 90%' {
            InModuleScope UltraTree {
                $result = Get-DiskHealthTag -UsedPercent 95
                $result.Text | Should -Be "Critical"
                $result.Class | Should -Be "expired"
            }
        }

        It 'Returns Warning for usage between 75% and 90%' {
            InModuleScope UltraTree {
                $result = Get-DiskHealthTag -UsedPercent 80
                $result.Text | Should -Be "Warning"
                $result.Class | Should -Be "disabled"
            }
        }

        It 'Returns Healthy for usage under 75%' {
            InModuleScope UltraTree {
                $result = Get-DiskHealthTag -UsedPercent 50
                $result.Text | Should -Be "Healthy"
                $result.Class | Should -Be ""
            }
        }

        It 'Returns Critical at exactly 91%' {
            InModuleScope UltraTree {
                $result = Get-DiskHealthTag -UsedPercent 91
                $result.Text | Should -Be "Critical"
            }
        }

        It 'Returns Warning at exactly 76%' {
            InModuleScope UltraTree {
                $result = Get-DiskHealthTag -UsedPercent 76
                $result.Text | Should -Be "Warning"
            }
        }
    }
}
