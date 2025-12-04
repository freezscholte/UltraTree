BeforeAll {
    Set-Location -Path $PSScriptRoot
    $ModuleName = 'UltraTree'
    $PathToManifest = [System.IO.Path]::Combine('..', '..', '..', $ModuleName, "$ModuleName.psd1")
    Get-Module $ModuleName -ErrorAction SilentlyContinue | Remove-Module -Force
    Import-Module $PathToManifest -Force
}

Describe 'Format-ByteSize' -Tag Unit {
    Context 'Zero and small values' {
        It 'Formats 0 bytes correctly' {
            InModuleScope UltraTree {
                Format-ByteSize -Bytes 0 | Should -Be "0 B"
            }
        }

        It 'Formats small bytes correctly' {
            InModuleScope UltraTree {
                Format-ByteSize -Bytes 500 | Should -Be "500.00 B"
            }
        }
    }

    Context 'Kilobytes' {
        It 'Formats 1 KB correctly' {
            InModuleScope UltraTree {
                Format-ByteSize -Bytes 1024 | Should -Be "1.00 KB"
            }
        }

        It 'Formats 2 KB correctly' {
            InModuleScope UltraTree {
                Format-ByteSize -Bytes 2048 | Should -Be "2.00 KB"
            }
        }
    }

    Context 'Megabytes' {
        It 'Formats 1 MB correctly' {
            InModuleScope UltraTree {
                Format-ByteSize -Bytes (1024 * 1024) | Should -Be "1.00 MB"
            }
        }

        It 'Formats 100 MB correctly' {
            InModuleScope UltraTree {
                Format-ByteSize -Bytes (100 * 1024 * 1024) | Should -Be "100.00 MB"
            }
        }
    }

    Context 'Gigabytes' {
        It 'Formats 1 GB correctly' {
            InModuleScope UltraTree {
                Format-ByteSize -Bytes (1024 * 1024 * 1024) | Should -Be "1.00 GB"
            }
        }
    }

    Context 'Terabytes' {
        It 'Formats 1 TB correctly' {
            InModuleScope UltraTree {
                Format-ByteSize -Bytes (1024L * 1024 * 1024 * 1024) | Should -Be "1.00 TB"
            }
        }
    }

    Context 'Decimal places parameter' {
        It 'Respects 0 decimal places' {
            InModuleScope UltraTree {
                Format-ByteSize -Bytes 1536 -Decimals 0 | Should -Be "2 KB"
            }
        }

        It 'Respects 1 decimal place' {
            InModuleScope UltraTree {
                Format-ByteSize -Bytes 1536 -Decimals 1 | Should -Be "1.5 KB"
            }
        }

        It 'Respects 3 decimal places' {
            InModuleScope UltraTree {
                Format-ByteSize -Bytes 1536 -Decimals 3 | Should -Be "1.500 KB"
            }
        }
    }
}
