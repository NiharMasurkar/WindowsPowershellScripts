<#
.SYNOPSIS
    Forces OneDrive to "Free up space" by converting files to online-only 
    across all local user profiles.
.DESCRIPTION
    Loops through C:\Users, detects active OneDrive sync directories, 
    and applies 'attrib +U -P' to dehydrate local file caches.
#>

# Define the base user profiles directory
$ProfilesPath = "C:\Users"

# Get all actual user folders, excluding system profiles
$UserProfiles = Get-ChildItem -Path $ProfilesPath -Directory | 
                Where-Object { $_.Name -notmatch "Public|Default|All Users|NetworkService|LocalService" }

Write-Host "Starting cross-profile OneDrive cache cleanup..." -ForegroundColor Cyan

foreach ($Profile in $UserProfiles) {
    $ProfilePath = $Profile.FullName
    Write-Host "`nProcessing profile: $($Profile.Name)" -ForegroundColor Yellow
    
    # Define potential OneDrive folder names (Personal, Business/Commercial)
    $OneDriveTargets = @(
        "$ProfilePath\OneDrive",
        "$ProfilePath\OneDrive - *"
    )
    
    # Resolve actual paths if they exist
    $ActivePaths = Get-Item -Path $OneDriveTargets -ErrorAction SilentlyContinue

    if (-not $ActivePaths) {
        Write-Host "   No active OneDrive folders found for this user." -ForegroundColor DarkGray
        continue
    }

    foreach ($TargetFolder in $ActivePaths) {
        Write-Host "   Found: $($TargetFolder.FullName)" -ForegroundColor White
        
        # Target all subdirectories and files inside the OneDrive folder
        $PathToClean = Join-Path $TargetFolder.FullName "*"
        
        try {
            Write-Host "   Dehydrating local cache (Freeing up space)..." -ForegroundColor Gray
            
            # +U makes files online-only, -P removes the "always keep on this device" flag
            # /S processes matching files in the current folder and all subfolders
            # /D processes folders as well
            & attrib.exe +U -P "$PathToClean" /S /D 2>$null
            
            Write-Host "   Successfully processed folder." -ForegroundColor Green
        }
        catch {
            Write-Warning "   Failed to process attributes on $($TargetFolder.FullName). Reason: $_"
        }
    }
}

Write-Host "`nOneDrive space cleanup complete across all profiles." -ForegroundColor Cyan
