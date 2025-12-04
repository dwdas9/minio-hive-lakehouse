# Master setup script - Sets up both PART-A and optionally PART-B

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "  MinIO-Hive-Lakehouse Master Setup" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

# Setup PART-A first
Write-Host "Setting up PART-A (Core Infrastructure)..." -ForegroundColor Yellow
Write-Host ""
Set-Location PART-A
& .\setup.ps1
Set-Location ..

Write-Host ""
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
$setupB = Read-Host "Do you want to setup PART-B (Learning Projects)? (y/n)"

if ($setupB -eq "y" -or $setupB -eq "Y") {
    Write-Host ""
    Write-Host "Setting up PART-B (Streaming Analytics)..." -ForegroundColor Yellow
    Write-Host ""
    Set-Location PART-B
    & .\setup.ps1
    Set-Location ..
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Quick commands:"
Write-Host "  cd PART-A; .\start.ps1   - Start core lakehouse"
Write-Host "  cd PART-A; .\stop.ps1    - Stop core lakehouse"
Write-Host "  cd PART-B; .\setup.ps1   - Start learning projects"
Write-Host ""
