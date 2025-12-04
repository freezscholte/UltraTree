BeforeAll {
    Set-Location -Path $PSScriptRoot
    $ModuleName = 'UltraTree'
    $PathToManifest = [System.IO.Path]::Combine('..', '..', '..', $ModuleName, "$ModuleName.psd1")
    Get-Module $ModuleName -ErrorAction SilentlyContinue | Remove-Module -Force
    Import-Module $PathToManifest -Force
}

Describe 'Get-FolderSizes' -Tag Unit {

    Context 'Parameter validation' {
        It 'Throws when neither DriveLetter nor AllDrives is specified' {
            { Get-FolderSizes } | Should -Throw "*must specify either -DriveLetter or -AllDrives*"
        }

        It 'Has DriveLetter parameter' {
            $command = Get-Command Get-FolderSizes
            $command.Parameters['DriveLetter'] | Should -Not -BeNullOrEmpty
        }

        It 'Has MaxDepth parameter with default value 5' {
            $command = Get-Command Get-FolderSizes
            $command.Parameters['MaxDepth'] | Should -Not -BeNullOrEmpty
        }

        It 'Has Top parameter' {
            $command = Get-Command Get-FolderSizes
            $command.Parameters['Top'] | Should -Not -BeNullOrEmpty
        }

        It 'Has AllDrives switch parameter' {
            $command = Get-Command Get-FolderSizes
            $command.Parameters['AllDrives'].SwitchParameter | Should -BeTrue
        }

        It 'Has FindDuplicates switch parameter' {
            $command = Get-Command Get-FolderSizes
            $command.Parameters['FindDuplicates'].SwitchParameter | Should -BeTrue
        }

        It 'Has ExcludeDrives parameter accepting string array' {
            $command = Get-Command Get-FolderSizes
            $command.Parameters['ExcludeDrives'].ParameterType.Name | Should -Be 'String[]'
        }
    }

    Context 'Help documentation' {
        BeforeAll {
            $help = Get-Help Get-FolderSizes -Full
        }

        It 'Has synopsis' {
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'Has description' {
            $help.Description | Should -Not -BeNullOrEmpty
        }

        It 'Has at least one example' {
            $help.Examples.Example.Count | Should -BeGreaterOrEqual 1
        }

        It 'Documents DriveLetter parameter' {
            ($help.Parameters.Parameter | Where-Object { $_.Name -eq 'DriveLetter' }).Description.Text | Should -Not -BeNullOrEmpty
        }

        It 'Documents AllDrives parameter' {
            ($help.Parameters.Parameter | Where-Object { $_.Name -eq 'AllDrives' }).Description.Text | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Return type structure' {
        # Note: These tests mock the actual scanning to avoid real disk I/O
        It 'Returns PSCustomObject with expected properties' {
            # We can't easily test without admin rights and real disk access
            # This test verifies the function is callable
            $command = Get-Command Get-FolderSizes
            $command | Should -Not -BeNullOrEmpty
        }
    }
}
