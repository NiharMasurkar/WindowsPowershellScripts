<#
.SYNOPSIS
    Shows largest folders and files on Local Disk C:
.DESCRIPTION
    Scans C:\ and reports:
    1. Size of top-level folders in C:\
    2. Largest individual files in C:\
#>

Write-Host "=== C Drive Storage Usage Report ===" -ForegroundColor Cyan
Write-Host "Scanning C:\. This may take several minutes..." -ForegroundColor Yellow

# Function to convert bytes to GB
function Convert-ToGB {
    param (
        [double]$Bytes
    )

    return [math]::Round($Bytes / 1GB, 2)
}

# 1. Show total C drive usage
$Drive = Get-PSDrive C

$UsedGB = Convert-ToGB ($Drive.Used)
$FreeGB = Convert-ToGB ($Drive.Free)
$TotalGB = Convert-ToGB ($Drive.Used + $Drive.Free)

Write-Host "`n=== C Drive Summary ===" -ForegroundColor Cyan
Write-Host "Total Size : $TotalGB GB"
Write-Host "Used Space : $UsedGB GB"
Write-Host "Free Space : $FreeGB GB"

# 2. Get size of each top-level folder in C:\
Write-Host "`n=== Largest Top-Level Folders in C:\ ===" -ForegroundColor Cyan

$Folders = Get-ChildItem "C:\" -Directory -Force -ErrorAction SilentlyContinue

$FolderSizes = foreach ($Folder in $Folders) {
    Write-Host "Scanning folder: $($Folder.FullName)" -ForegroundColor DarkGray

    $Size = 0

    try {
        $Size = (Get-ChildItem $Folder.FullName -Recurse -Force -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
    }
    catch {
        $Size = 0
    }

    [PSCustomObject]@{
        Folder = $Folder.FullName
        SizeGB = Convert-ToGB $Size
    }
}

$FolderSizes |
    Sort-Object SizeGB -Descending |
    Format-Table -AutoSize

# 3. Show largest individual files in C:\
Write-Host "`n=== Largest Individual Files in C:\ ===" -ForegroundColor Cyan

$LargestFiles = Get-ChildItem "C:\" -Recurse -Force -File -ErrorAction SilentlyContinue |
    Sort-Object Length -Descending |
    Select-Object -First 30 `
        @{Name="SizeGB"; Expression={Convert-ToGB $_.Length}},
        FullName

$LargestFiles | Format-Table -AutoSize

Write-Host "`n=== Scan Complete ===" -ForegroundColor Green
