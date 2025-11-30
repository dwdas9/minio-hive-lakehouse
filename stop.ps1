# STOP - Stop the Hive-Iceberg-MinIO Lakehouse
# Containers are stopped but preserved

Write-Host "Stopping Jupyter notebook..."
docker-compose -f spark-notebook.yml stop

Write-Host "Stopping infrastructure..."
docker-compose stop

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Lakehouse stopped." -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Containers are stopped but preserved."
Write-Host "Run .\start.ps1 to start again quickly."
Write-Host ""
Write-Host "To remove containers completely, run:"
Write-Host "  .\nuke.ps1"
Write-Host ""
