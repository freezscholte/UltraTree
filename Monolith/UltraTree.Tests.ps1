#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for CF-UltraTreesizeNinja-v8.ps1

.DESCRIPTION
    Unit tests for helper functions, theme system, and HTML generation.
    Run with: Invoke-Pester -Path .\CF-UltraTreesizeNinja-v8.Tests.ps1

.NOTES
    Requires Pester 5.x
    Install with: Install-Module -Name Pester -Force -SkipPublisherCheck
#>

BeforeAll {
    # Load the script in test mode (doesn't execute main scan)
    . $PSScriptRoot/CF-UltraTreesizeNinja-v8.ps1 -TestMode
}

Describe 'Configuration' {
    Context 'Config structure' {
        It 'Has required top-level keys' {
            $script:Config | Should -Not -BeNullOrEmpty
            $script:Config.Version | Should -Not -BeNullOrEmpty
            $script:Config.Thresholds | Should -Not -BeNullOrEmpty
            $script:Config.Display | Should -Not -BeNullOrEmpty
            $script:Config.DiskHealth | Should -Not -BeNullOrEmpty
            $script:Config.Theme | Should -Not -BeNullOrEmpty
        }

        It 'Has version 8.0.0' {
            $script:Config.Version | Should -Be "8.0.0"
        }

        It 'Has theme colors' {
            $script:Config.Theme.Colors.Danger | Should -Be "#d9534f"
            $script:Config.Theme.Colors.Warning | Should -Be "#f0ad4e"
            $script:Config.Theme.Colors.Info | Should -Be "#5bc0de"
            $script:Config.Theme.Colors.Success | Should -Be "#4ECDC4"
        }

        It 'Has theme icons' {
            $script:Config.Theme.Icons.Folder | Should -Be "fas fa-folder"
            $script:Config.Theme.Icons.File | Should -Be "fas fa-file"
            $script:Config.Theme.Icons.Drive | Should -Be "fas fa-hdd"
        }
    }

    Context 'Cleanup categories' {
        It 'Has 7 cleanup categories' {
            $script:CleanupCategories.Count | Should -Be 7
        }

        It 'Each category has required properties' {
            foreach ($cat in $script:CleanupCategories) {
                $cat.Name | Should -Not -BeNullOrEmpty
                $cat.DisplayName | Should -Not -BeNullOrEmpty
                $cat.Patterns | Should -Not -BeNullOrEmpty
                $cat.Icon | Should -Not -BeNullOrEmpty
                $cat.Severity | Should -Not -BeNullOrEmpty
                $cat.Description | Should -Not -BeNullOrEmpty
            }
        }

        It 'Has recycleBin category' {
            $recycleBin = $script:CleanupCategories | Where-Object { $_.Name -eq "recycleBin" }
            $recycleBin | Should -Not -BeNullOrEmpty
            $recycleBin.Patterns | Should -Contain '\$Recycle.Bin'
        }
    }
}

Describe 'Format-ByteSize' {
    It 'Formats 0 bytes correctly' {
        Format-ByteSize -Bytes 0 | Should -Be "0 B"
    }

    It 'Formats bytes correctly' {
        Format-ByteSize -Bytes 500 | Should -Be "500.00 B"
    }

    It 'Formats KB correctly' {
        Format-ByteSize -Bytes 1024 | Should -Be "1.00 KB"
        Format-ByteSize -Bytes 2048 | Should -Be "2.00 KB"
    }

    It 'Formats MB correctly' {
        Format-ByteSize -Bytes (1024 * 1024) | Should -Be "1.00 MB"
        Format-ByteSize -Bytes (100 * 1024 * 1024) | Should -Be "100.00 MB"
    }

    It 'Formats GB correctly' {
        Format-ByteSize -Bytes (1024 * 1024 * 1024) | Should -Be "1.00 GB"
    }

    It 'Formats TB correctly' {
        Format-ByteSize -Bytes (1024L * 1024 * 1024 * 1024) | Should -Be "1.00 TB"
    }

    It 'Respects decimal places' {
        Format-ByteSize -Bytes 1536 -Decimals 0 | Should -Be "2 KB"
        Format-ByteSize -Bytes 1536 -Decimals 1 | Should -Be "1.5 KB"
        Format-ByteSize -Bytes 1536 -Decimals 3 | Should -Be "1.500 KB"
    }
}

Describe 'Theme Functions' {
    Context 'Get-ThemeColor' {
        It 'Returns correct color for Danger' {
            Get-ThemeColor -Severity "Danger" | Should -Be "#d9534f"
        }

        It 'Returns correct color for Warning' {
            Get-ThemeColor -Severity "Warning" | Should -Be "#f0ad4e"
        }

        It 'Returns correct color for Info' {
            Get-ThemeColor -Severity "Info" | Should -Be "#5bc0de"
        }

        It 'Returns correct color for Success' {
            Get-ThemeColor -Severity "Success" | Should -Be "#4ECDC4"
        }
    }

    Context 'Get-ThemeIcon' {
        It 'Returns correct icon for Folder' {
            Get-ThemeIcon -IconName "Folder" | Should -Be "fas fa-folder"
        }

        It 'Returns correct icon for Warning' {
            Get-ThemeIcon -IconName "Warning" | Should -Be "fa-solid fa-triangle-exclamation"
        }
    }

    Context 'Get-SeverityStyle' {
        It 'Returns hashtable with Color, Icon, and Class' {
            $style = Get-SeverityStyle -Severity "Warning"
            $style.Color | Should -Be "#f0ad4e"
            $style.Icon | Should -Be "fa-solid fa-triangle-exclamation"
            $style.Class | Should -Be "warning"
        }
    }
}

Describe 'Get-SizeCategory' {
    It 'Returns danger for sizes over 100GB' {
        Get-SizeCategory -SizeBytes (101GB) | Should -Be "danger"
    }

    It 'Returns warning for sizes between 50GB and 100GB' {
        Get-SizeCategory -SizeBytes (75GB) | Should -Be "warning"
    }

    It 'Returns other for sizes between 10GB and 50GB' {
        Get-SizeCategory -SizeBytes (25GB) | Should -Be "other"
    }

    It 'Returns unknown for sizes between 1GB and 10GB' {
        Get-SizeCategory -SizeBytes (5GB) | Should -Be "unknown"
    }

    It 'Returns success for sizes under 1GB' {
        Get-SizeCategory -SizeBytes (500MB) | Should -Be "success"
    }
}

Describe 'Get-DiskHealthTag' {
    It 'Returns Critical for usage over 90%' {
        $result = Get-DiskHealthTag -UsedPercent 95
        $result.Text | Should -Be "Critical"
        $result.Class | Should -Be "expired"
    }

    It 'Returns Warning for usage between 75% and 90%' {
        $result = Get-DiskHealthTag -UsedPercent 80
        $result.Text | Should -Be "Warning"
        $result.Class | Should -Be "disabled"
    }

    It 'Returns Healthy for usage under 75%' {
        $result = Get-DiskHealthTag -UsedPercent 50
        $result.Text | Should -Be "Healthy"
        $result.Class | Should -Be ""
    }
}

Describe 'Get-WastedSpaceSeverity' {
    It 'Returns Danger for wasted space over 500MB' {
        Get-WastedSpaceSeverity -WastedBytes (600MB) | Should -Be "Danger"
    }

    It 'Returns Warning for wasted space between 100MB and 500MB' {
        Get-WastedSpaceSeverity -WastedBytes (200MB) | Should -Be "Warning"
    }

    It 'Returns Info for wasted space under 100MB' {
        Get-WastedSpaceSeverity -WastedBytes (50MB) | Should -Be "Info"
    }
}

Describe 'Get-CleanupCategoryInfo' {
    It 'Returns correct info for recycleBin category' {
        $info = Get-CleanupCategoryInfo -CategoryName "recycleBin"
        $info.Icon | Should -Be "fas fa-trash"
        $info.Color | Should -Be "#f0ad4e"
    }

    It 'Returns correct info for temp category' {
        $info = Get-CleanupCategoryInfo -CategoryName "temp"
        $info.Icon | Should -Be "fas fa-clock"
        $info.Color | Should -Be "#5bc0de"
    }

    It 'Returns fallback for unknown category' {
        $info = Get-CleanupCategoryInfo -CategoryName "unknownCategory"
        $info.Icon | Should -Be "fas fa-folder"
        $info.Color | Should -Be "#5bc0de"
    }
}

Describe 'Error Tracking' {
    BeforeEach {
        Clear-ErrorLog
    }

    It 'Starts with empty error log' {
        $script:ErrorLog.Count | Should -Be 0
    }

    It 'Adds errors to the log' {
        Add-ScanError -Path "C:\test" -Category "access" -Message "Access denied"
        $script:ErrorLog.Count | Should -Be 1
        $script:ErrorLog[0].Path | Should -Be "C:\test"
        $script:ErrorLog[0].Category | Should -Be "access"
    }

    It 'Get-ErrorSummary returns null when no errors' {
        Get-ErrorSummary | Should -BeNullOrEmpty
    }

    It 'Get-ErrorSummary returns summary with errors' {
        Add-ScanError -Path "C:\test1" -Category "access" -Message "Access denied"
        Add-ScanError -Path "C:\test2" -Category "io" -Message "IO error"
        Add-ScanError -Path "C:\test3" -Category "access" -Message "Another access error"

        $summary = Get-ErrorSummary
        $summary | Should -Match "3 errors"
        $summary | Should -Match "2 access"
        $summary | Should -Match "1 io"
    }

    It 'Clear-ErrorLog clears the log' {
        Add-ScanError -Path "C:\test" -Category "access" -Message "Test"
        $script:ErrorLog.Count | Should -Be 1
        Clear-ErrorLog
        $script:ErrorLog.Count | Should -Be 0
    }
}

Describe 'Input Validation' {
    It 'Throws on negative MaxDepth' {
        { Test-ScanParameters -MaxDepth -1 -Top 10 -MinDuplicateSize 1MB } | Should -Throw "*MaxDepth must be at least 1*"
    }

    It 'Throws on MaxDepth over 20' {
        { Test-ScanParameters -MaxDepth 25 -Top 10 -MinDuplicateSize 1MB } | Should -Throw "*MaxDepth cannot exceed 20*"
    }

    It 'Throws on negative Top' {
        { Test-ScanParameters -MaxDepth 5 -Top 0 -MinDuplicateSize 1MB } | Should -Throw "*Top must be at least 1*"
    }

    It 'Throws on Top over 1000' {
        { Test-ScanParameters -MaxDepth 5 -Top 1500 -MinDuplicateSize 1MB } | Should -Throw "*Top cannot exceed 1000*"
    }

    It 'Throws on negative MinDuplicateSize' {
        { Test-ScanParameters -MaxDepth 5 -Top 10 -MinDuplicateSize -1 } | Should -Throw "*MinDuplicateSize cannot be negative*"
    }

    It 'Passes with valid parameters' {
        { Test-ScanParameters -MaxDepth 5 -Top 40 -MinDuplicateSize 10MB } | Should -Not -Throw
    }
}

Describe 'HTML Generation' {
    Context 'New-HtmlStatCard' {
        It 'Generates valid stat card HTML' {
            $html = New-HtmlStatCard -Value "100 GB" -Description "Test Desc" -Color "#ff0000"
            $html | Should -Match 'class="stat-card"'
            $html | Should -Match 'class="stat-value"'
            $html | Should -Match 'class="stat-desc"'
            $html | Should -Match '100 GB'
            $html | Should -Match 'Test Desc'
            $html | Should -Match '#ff0000'
        }

        It 'Includes icon when provided' {
            $html = New-HtmlStatCard -Value "5" -Description "Items" -Icon "fas fa-folder"
            $html | Should -Match 'fas fa-folder'
        }
    }

    Context 'New-HtmlInfoCard' {
        It 'Generates info card with correct type' {
            $html = New-HtmlInfoCard -Title "Test" -Description "Desc" -Type "Warning"
            $html | Should -Match 'class="info-card warning"'
            $html | Should -Match 'fa-solid fa-triangle-exclamation'
        }

        It 'Info type has no extra class' {
            $html = New-HtmlInfoCard -Title "Test" -Description "Desc" -Type "Info"
            $html | Should -Match 'class="info-card"'
            $html | Should -Not -Match 'class="info-card info"'
        }
    }

    Context 'New-HtmlTag' {
        It 'Generates basic tag' {
            $html = New-HtmlTag -Text "Healthy"
            $html | Should -Match 'class="tag"'
            $html | Should -Match 'Healthy'
        }

        It 'Adds type class' {
            $html = New-HtmlTag -Text "Critical" -Type "expired"
            $html | Should -Match 'class="tag expired"'
        }
    }

    Context 'New-HtmlCard' {
        It 'Generates card with title and body' {
            $html = New-HtmlCard -Title "Test Card" -Body "<p>Content</p>"
            $html | Should -Match 'class="card flex-grow-1"'
            $html | Should -Match 'class="card-title-box"'
            $html | Should -Match 'Test Card'
            $html | Should -Match '<p>Content</p>'
        }

        It 'Includes icon when provided' {
            $html = New-HtmlCard -Title "Test" -Icon "fas fa-folder" -Body "Content"
            $html | Should -Match 'fas fa-folder'
        }

        It 'Applies body style' {
            $html = New-HtmlCard -Title "Test" -Body "Content" -BodyStyle "padding: 0;"
            $html | Should -Match 'style="padding: 0;"'
        }
    }

    Context 'New-HtmlBarChart' {
        It 'Returns empty string for null items' {
            New-HtmlBarChart -Items $null | Should -Be ""
        }

        It 'Returns empty string for empty array' {
            New-HtmlBarChart -Items @() | Should -Be ""
        }

        It 'Generates chart with items' {
            $items = @(
                @{ Label = "Folder1"; Value = 1GB }
                @{ Label = "Folder2"; Value = 500MB }
            )
            $html = New-HtmlBarChart -Items $items -Title "Test Chart"
            $html | Should -Match 'charts-css bar'
            $html | Should -Match 'Test Chart'
            $html | Should -Match 'Folder1'
            $html | Should -Match 'Folder2'
        }
    }

    Context 'New-HtmlDuplicatesTable' {
        It 'Returns empty string for null groups' {
            New-HtmlDuplicatesTable -DuplicateGroups $null -TotalWasted 0 | Should -Be ""
        }

        It 'Returns empty string for empty groups' {
            New-HtmlDuplicatesTable -DuplicateGroups @() -TotalWasted 0 | Should -Be ""
        }

        It 'Generates table with duplicate groups' {
            $groups = @(
                [PSCustomObject]@{
                    FileSize = 100MB
                    WastedSpace = 100MB
                    Files = @("C:\path1\file.exe", "C:\path2\file.exe")
                }
            )
            $html = New-HtmlDuplicatesTable -DuplicateGroups $groups -TotalWasted 100MB
            $html | Should -Match 'Duplicate Files'
            $html | Should -Match 'file.exe'
            $html | Should -Match 'Wasted'
        }
    }
}

Describe 'Integration' {
    It 'Script loads without errors in TestMode' {
        # This test passes if BeforeAll succeeded
        $script:Config.Version | Should -Be "8.0.0"
    }

    It 'All required functions exist' {
        Get-Command Format-ByteSize | Should -Not -BeNullOrEmpty
        Get-Command Get-ThemeColor | Should -Not -BeNullOrEmpty
        Get-Command Get-ThemeIcon | Should -Not -BeNullOrEmpty
        Get-Command Get-SeverityStyle | Should -Not -BeNullOrEmpty
        Get-Command Get-SizeCategory | Should -Not -BeNullOrEmpty
        Get-Command Get-DiskHealthTag | Should -Not -BeNullOrEmpty
        Get-Command Get-WastedSpaceSeverity | Should -Not -BeNullOrEmpty
        Get-Command Test-ScanParameters | Should -Not -BeNullOrEmpty
        Get-Command New-HtmlCard | Should -Not -BeNullOrEmpty
        Get-Command New-HtmlStatCard | Should -Not -BeNullOrEmpty
        Get-Command New-HtmlInfoCard | Should -Not -BeNullOrEmpty
        Get-Command New-HtmlTable | Should -Not -BeNullOrEmpty
        Get-Command New-HtmlBarChart | Should -Not -BeNullOrEmpty
        Get-Command Get-FolderSizes | Should -Not -BeNullOrEmpty
        Get-Command ConvertTo-NinjaOneHtml | Should -Not -BeNullOrEmpty
    }
}
