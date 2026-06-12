# Define the root path for all user profiles
$ProfilesPath = "C:\Users"

# Get all directories inside C:\Users, excluding standard system/public folders
$UserProfiles = Get-ChildItem -Path $ProfilesPath -Directory | Where-Object { 
    $_.Name -notin "Public", "Default", "All Users", "Default User" 
}

Write-Host "Starting User Profile Temp Data Cleanup..." -ForegroundColor Cyan

foreach ($Profile in $UserProfiles) {
    # Construct the path to the individual user's Local Temp directory
    $TempPath = Join-Path -Path $Profile.FullName -ChildPath "AppData\Local\Temp"
    
    if (Test-Path -Path $TempPath) {
        Write-Host "Cleaning temp data for profile: $($Profile.Name)..." -ForegroundColor Yellow
        
        # Target all files and subfolders within the Temp folder
        $TempItems = Get-ChildItem -Path $TempPath -Force -Recurse -ErrorAction SilentlyContinue
        
        foreach ($Item in $TempItems) {
            try {
                # Attempt deletion; SilentlyContinue skips files currently locked or in use
                Remove-Item -Path $Item.FullName -Recurse -Force -ErrorAction SilentlyContinue
            }
            catch {
                # Caught exceptions are ignored so the loop continues seamlessly
            }
        }
    }
}

Write-Host "Cleanup completed successfully!" -ForegroundColor Green
