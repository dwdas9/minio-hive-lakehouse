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

# Function to download file with verification
function Download-Jar {
    param(
        [string]$Url,
        [string]$Output,
        [string]$Name
    )
    
    # Remove if it's a directory (from failed download)
    if (Test-Path $Output -PathType Container) {
        Remove-Item $Output -Recurse -Force
    }
    
    # Download only if file doesn't exist or is invalid
    if (-not (Test-Path $Output -PathType Leaf)) {
        Write-Host "Downloading $Name..."
        try {
            # Use TLS 1.2
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $Url -OutFile $Output -ErrorAction Stop
            
            # Verify it's actually a file with content
            if ((Test-Path $Output) -and ((Get-Item $Output).Length -gt 0)) {
                Write-Host "√ $Name downloaded successfully" -ForegroundColor Green
            } else {
                Write-Host "× Download failed: file is empty" -ForegroundColor Red
                Remove-Item $Output -Force -ErrorAction SilentlyContinue
                exit 1
            }
        } catch {
            Write-Host "× Download failed for $Name" -ForegroundColor Red
            Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "√ $Name already exists" -ForegroundColor Green
    }
}

# Download required JARs
Download-Jar `
    -Url "https://jdbc.postgresql.org/download/postgresql-42.6.0.jar" `
    -Output (Join-Path $LibDir "postgresql-42.6.0.jar") `
    -Name "PostgreSQL JDBC driver"

Download-Jar `
    -Url "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar" `
    -Output (Join-Path $LibDir "hadoop-aws-3.3.4.jar") `
    -Name "Hadoop AWS JAR"

Download-Jar `
    -Url "https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar" `
    -Output (Join-Path $LibDir "aws-java-sdk-bundle-1.12.262.jar") `
    -Name "AWS SDK bundle"

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
