# START - Starts existing stopped containers
# Use this daily to resume work

Write-Host "Starting containers..."

docker-compose start
docker-compose -f spark-notebook.yml start

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
