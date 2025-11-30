# NUKE - Complete destruction! Removes all containers, volumes, and data
# Use this when you want to start completely fresh

Write-Host "==========================================" -ForegroundColor Red
Write-Host "NUKE - Complete Cleanup" -ForegroundColor Red
Write-Host "==========================================" -ForegroundColor Red
Write-Host ""
Write-Host "This will PERMANENTLY DELETE:" -ForegroundColor Yellow
Write-Host "  - All containers"
Write-Host "  - All data in MinIO (your files)"
Write-Host "  - All data in PostgreSQL (your metastore)"
Write-Host "  - All Iceberg tables and metadata"
Write-Host ""

$confirm = Read-Host "Are you sure? Type 'yes' to confirm"

if ($confirm -ne "yes") {
    Write-Host "Cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Removing Spark notebook..."
docker-compose -f spark-notebook.yml down -v 2>$null

Write-Host "Removing infrastructure..."
docker-compose down -v

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "√ Everything has been nuked!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "All containers and data removed."
Write-Host "Run .\setup.ps1 to create fresh containers."
Write-Host ""
