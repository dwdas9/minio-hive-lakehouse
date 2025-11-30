# FIRST TIME SETUP - Creates and starts all containers
# Run this once when setting up the lakehouse for the first time

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LibDir = Join-Path $ScriptDir "lib"

# Create lib directory if it doesn't exist
if (-not (Test-Path $LibDir)) {
    New-Item -ItemType Directory -Path $LibDir | Out-Null
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "First-time Setup: Hive-Iceberg-MinIO Lakehouse" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Download required JARs if not present
$pgJar = Join-Path $LibDir "postgresql-42.6.0.jar"
if (-not (Test-Path $pgJar)) {
    Write-Host "Downloading PostgreSQL JDBC driver..."
    Invoke-WebRequest -Uri "https://jdbc.postgresql.org/download/postgresql-42.6.0.jar" -OutFile $pgJar
    Write-Host "√ PostgreSQL driver downloaded" -ForegroundColor Green
}

$hadoopJar = Join-Path $LibDir "hadoop-aws-3.3.4.jar"
if (-not (Test-Path $hadoopJar)) {
    Write-Host "Downloading Hadoop AWS JAR..."
    Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar" -OutFile $hadoopJar
    Write-Host "√ Hadoop AWS downloaded" -ForegroundColor Green
}

$awsJar = Join-Path $LibDir "aws-java-sdk-bundle-1.12.262.jar"
if (-not (Test-Path $awsJar)) {
    Write-Host "Downloading AWS SDK bundle..."
    Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar" -OutFile $awsJar
    Write-Host "√ AWS SDK downloaded" -ForegroundColor Green
}

Write-Host ""
Write-Host "Creating and starting containers..."
docker-compose up -d

Write-Host ""
Write-Host "Waiting for Hive Metastore to be ready..."
Start-Sleep -Seconds 10

# Wait for metastore
for ($i = 1; $i -le 30; $i++) {
    $logs = docker-compose logs hive-metastore 2>&1
    if ($logs -match "Starting Hive Metastore Server") {
        Write-Host "√ Hive Metastore is ready!" -ForegroundColor Green
        break
    }
    Write-Host "  Waiting... ($i/30)"
    Start-Sleep -Seconds 2
}

Write-Host ""
Write-Host "Creating Spark notebook container..."
docker-compose -f spark-notebook.yml up -d

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "√ Setup Complete! Lakehouse is running!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Jupyter:      http://localhost:8888"
Write-Host "  MinIO:        http://localhost:9001"
Write-Host "  Spark UI:     http://localhost:4040 (when running queries)"
Write-Host ""
Write-Host "  MinIO login:  minioadmin / minioadmin"
Write-Host ""
Write-Host "Open the getting_started.ipynb notebook to begin."
Write-Host ""
Write-Host "Daily usage:"
Write-Host "  .\stop.ps1   - Stop containers (end of day)"
Write-Host "  .\start.ps1  - Start containers (next day)"
Write-Host "  .\nuke.ps1   - Delete everything and start fresh"
Write-Host ""
