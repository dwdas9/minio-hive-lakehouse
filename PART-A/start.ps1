# START - Starts the lakehouse (creates containers if needed)
# Use this daily to resume work or after machine restart

Write-Host "Starting lakehouse..." -ForegroundColor Cyan
Write-Host ""

# Start core infrastructure (creates if doesn't exist)
docker-compose up -d

Write-Host "Waiting for services to be healthy..."
Start-Sleep -Seconds 10

# Start Jupyter notebook
docker-compose -f spark-notebook.yml up -d

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Lakehouse is running!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Jupyter:      http://localhost:8888"
Write-Host "  MinIO:        http://localhost:9001"
Write-Host "  Spark UI:     http://localhost:4040 (when running queries)"
Write-Host ""
Write-Host "  MinIO login:  minioadmin / minioadmin"
Write-Host ""
Write-Host "Tip: Run 'docker ps' to verify all containers are running" -ForegroundColor Yellow
Write-Host ""
