# Setup Script for Crypto Analytics Learning Project
# Windows PowerShell

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Crypto Analytics - Learning Project Setup" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check if main lakehouse is running
Write-Host "Checking if main lakehouse is running..." -ForegroundColor Yellow
$minioRunning = docker ps --filter "name=hive-minio" --filter "status=running" --format "{{.Names}}"
$hiveRunning = docker ps --filter "name=hive-metastore" --filter "status=running" --format "{{.Names}}"

if (-not $minioRunning -or -not $hiveRunning) {
    Write-Host "❌ Main lakehouse is not running!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please start the main lakehouse first:" -ForegroundColor Yellow
    Write-Host "  cd .." -ForegroundColor White
    Write-Host "  powershell -ExecutionPolicy Bypass -File .\start.ps1" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host "√ Main lakehouse is running" -ForegroundColor Green
Write-Host ""

# Check if dasnet network exists
Write-Host "Checking Docker network..." -ForegroundColor Yellow
$networkExists = docker network ls --filter "name=dasnet" --format "{{.Name}}"

if (-not $networkExists) {
    Write-Host "❌ Network 'dasnet' does not exist!" -ForegroundColor Red
    Write-Host ""
    Write-Host "The network should have been created by the main lakehouse." -ForegroundColor Yellow
    Write-Host "Please run the main setup first:" -ForegroundColor Yellow
    Write-Host "  cd .." -ForegroundColor White
    Write-Host "  powershell -ExecutionPolicy Bypass -File .\setup.ps1" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host "√ Network 'dasnet' exists" -ForegroundColor Green
Write-Host ""

# Start Kafka stack
Write-Host "Starting Kafka, Zookeeper, and Crypto Producer..." -ForegroundColor Yellow
docker-compose up -d

Write-Host ""
Write-Host "Waiting for Kafka to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# Check if services are healthy
$kafkaHealthy = docker ps --filter "name=crypto-kafka" --filter "health=healthy" --format "{{.Names}}"

if ($kafkaHealthy) {
    Write-Host "√ Kafka is healthy" -ForegroundColor Green
} else {
    Write-Host "⚠️ Kafka might still be starting up..." -ForegroundColor Yellow
    Write-Host "Check status with: docker-compose ps" -ForegroundColor White
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "√ Setup Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Services Available:" -ForegroundColor Yellow
Write-Host "  Kafka UI:        http://localhost:8080" -ForegroundColor White
Write-Host "  Kafka Broker:    localhost:9092" -ForegroundColor White
Write-Host "  Zookeeper:       localhost:2181" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Open Kafka UI to see live messages: http://localhost:8080" -ForegroundColor White
Write-Host "  2. Check producer logs: docker logs crypto-producer -f" -ForegroundColor White
Write-Host "  3. Read Phase 1 documentation: data-modeling\schema-design.md" -ForegroundColor White
Write-Host ""
Write-Host "To stop:" -ForegroundColor Yellow
Write-Host "  docker-compose stop" -ForegroundColor White
Write-Host ""
