<#
.SYNOPSIS
    C Drive Cleanup Script

.DESCRIPTION
    Safely clears Windows temp directories, user caches,
    the SoftwareDistribution folder, and empties the Recycle Bin.
    Also shows C: drive storage before and after cleanup.
#>

# Ensure script runs as Administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Please re-run this script as an Administrator!"
    Exit
}

# Function to convert bytes into readable GB format
function Convert-BytesToGB {
    param (
        [Parameter(Mandatory = $true)]
        [Int64]$Bytes
    )

    return "{0:N2} GB" -f ($Bytes / 1GB)
}

# Function to get C: drive storage information
function Get-CDriveStorage {
    $Drive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"

    $UsedSpace = $Drive.Size - $Drive.FreeSpace
    $FreePercent = ($Drive.FreeSpace / $Drive.Size) * 100

    return [PSCustomObject]@{
        Drive        = $Drive.DeviceID
        TotalSize    = Convert-BytesToGB $Drive.Size
        UsedSpace    = Convert-BytesToGB $UsedSpace
        FreeSpace    = Convert-BytesToGB $Drive.FreeSpace
        FreePercent  = "{0:N2}%" -f $FreePercent
        SizeBytes    = [Int64]$Drive.Size
        UsedBytes    = [Int64]$UsedSpace
        FreeBytes    = [Int64]$Drive.FreeSpace
    }
}

Write-Host "=== Starting C Drive Cleanup Operations ===" -ForegroundColor Cyan

# Capture C: drive storage before cleanup
Write-Host "`n=== C: Drive Storage Before Cleanup ===" -ForegroundColor Cyan
$BeforeCleanup = Get-CDriveStorage
$BeforeCleanup | Select-Object Drive, TotalSize, UsedSpace, FreeSpace, FreePercent | Format-Table -AutoSize

# 1. Empty the Recycle Bin for all drives
Write-Host "`n[1/5] Emptying the Recycle Bin..." -ForegroundColor Yellow
Clear-RecycleBin -Force -ErrorAction SilentlyContinue
Write-Host "Recycle bin cleared." -ForegroundColor Green

# 2. Clean System Temp Directory (C:\Windows\Temp)
Write-Host "`n[2/5] Cleaning Windows System Temp Folder..." -ForegroundColor Yellow
$SysTempPath = "C:\Windows\Temp\*"
Get-ChildItem -Path $SysTempPath -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "System Temp cleared." -ForegroundColor Green

# 3. Clean All Local User Temp Directories & Caches
Write-Host "`n[3/5] Cleaning User Temp Folders and Caches..." -ForegroundColor Yellow
$UserProfiles = Get-ChildItem -Path "C:\Users" -Directory

foreach ($Profile in $UserProfiles) {
    $PathsToClean = @(
        "C:\Users\$($Profile.Name)\AppData\Local\Temp\*",
        "C:\Users\$($Profile.Name)\AppData\Local\Microsoft\Windows\INetCache\*"
    )

    foreach ($Path in $PathsToClean) {
        if (Test-Path $Path) {
            Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host "User Temp and Internet cache cleared." -ForegroundColor Green

# 4. Flush the Windows Update Download Cache
# Requires stopping the Windows Update Service briefly
Write-Host "`n[4/5] Flushing Windows Update Download Cache..." -ForegroundColor Yellow
$UpdateService = Get-Service -Name "wuauserv" -ErrorAction SilentlyContinue

if ($UpdateService) {
    if ($UpdateService.Status -eq 'Running') {
        Write-Host "Stopping Windows Update service..." -ForegroundColor Gray
        Stop-Service -Name "wuauserv" -Force
    }

    $SoftwareDistPath = "C:\Windows\SoftwareDistribution\Download\*"

    Get-ChildItem -Path $SoftwareDistPath -Recurse -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "Starting Windows Update service..." -ForegroundColor Gray
    Start-Service -Name "wuauserv"

    Write-Host "Windows Update download cache cleared." -ForegroundColor Green
}

# 5. Run Native Windows Component Store Cleanup
Write-Host "`n[5/5] Analyzing and cleaning Component Store (WinSxS)..." -ForegroundColor Yellow
Write-Host "This step safely compresses/removes superseded system files and may take a few minutes." -ForegroundColor Gray

dism.exe /online /cleanup-image /startcomponentcleanup /resetbase

Write-Host "Component Store optimization complete." -ForegroundColor Green

# Capture C: drive storage after cleanup
Write-Host "`n=== C: Drive Storage After Cleanup ===" -ForegroundColor Cyan
$AfterCleanup = Get-CDriveStorage
$AfterCleanup | Select-Object Drive, TotalSize, UsedSpace, FreeSpace, FreePercent | Format-Table -AutoSize

# Calculate space freed
$SpaceFreedBytes = $AfterCleanup.FreeBytes - $BeforeCleanup.FreeBytes

Write-Host "`n=== Cleanup Summary ===" -ForegroundColor Cyan
Write-Host "Free space before cleanup : $($BeforeCleanup.FreeSpace)" -ForegroundColor White
Write-Host "Free space after cleanup  : $($AfterCleanup.FreeSpace)" -ForegroundColor White
Write-Host "Space freed               : $(Convert-BytesToGB $SpaceFreedBytes)" -ForegroundColor Green

Write-Host "`n=== C Drive Cleanup Finished Successfully ===" -ForegroundColor Cyan
