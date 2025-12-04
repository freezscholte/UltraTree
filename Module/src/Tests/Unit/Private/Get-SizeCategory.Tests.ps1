BeforeAll {
    Set-Location -Path $PSScriptRoot
    $ModuleName = 'UltraTree'
    $PathToManifest = [System.IO.Path]::Combine('..', '..', '..', $ModuleName, "$ModuleName.psd1")
    Get-Module $ModuleName -ErrorAction SilentlyContinue | Remove-Module -Force
    Import-Module $PathToManifest -Force
}

Describe 'Get-SizeCategory' -Tag Unit {
    Context 'Size categorization' {
        It 'Returns danger for sizes over 100GB' {
            InModuleScope UltraTree { Get-SizeCategory -SizeBytes (101GB) | Should -Be "danger" }
        }

        It 'Returns warning for sizes between 50GB and 100GB' {
            InModuleScope UltraTree { Get-SizeCategory -SizeBytes (75GB) | Should -Be "warning" }
        }

        It 'Returns other for sizes between 10GB and 50GB' {
            InModuleScope UltraTree { Get-SizeCategory -SizeBytes (25GB) | Should -Be "other" }
        }

        It 'Returns unknown for sizes between 1GB and 10GB' {
            InModuleScope UltraTree { Get-SizeCategory -SizeBytes (5GB) | Should -Be "unknown" }
        }

        It 'Returns success for sizes under 1GB' {
            InModuleScope UltraTree { Get-SizeCategory -SizeBytes (500MB) | Should -Be "success" }
        }
    }
}
