#!/bin/bash
# FIRST TIME SETUP - Creates and starts all containers
# Run this once when setting up the lakehouse for the first time

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$SCRIPT_DIR/lib"

echo "=========================================="
echo "First-time Setup: Hive-Iceberg-MinIO Lakehouse"
echo "=========================================="
echo ""

# Function to download file with verification
download_jar() {
    local url=$1
    local output=$2
    local name=$3
    
    # Remove if it's a directory (from failed download)
    if [ -d "$output" ]; then
        rm -rf "$output"
    fi
    
    # Download only if file doesn't exist or is invalid
    if [ ! -f "$output" ]; then
        echo "Downloading $name..."
        if curl -fsSL -o "$output" "$url"; then
            # Verify it's actually a file with content
            if [ -f "$output" ] && [ -s "$output" ]; then
                echo "✓ $name downloaded successfully"
            else
                echo "✗ Download failed: file is empty"
                rm -f "$output"
                exit 1
            fi
        else
            echo "✗ Download failed for $name"
            exit 1
        fi
    else
        echo "✓ $name already exists"
    fi
}

# Download required JARs
download_jar \
    "https://jdbc.postgresql.org/download/postgresql-42.6.0.jar" \
    "$SCRIPT_DIR/lib/postgresql-42.6.0.jar" \
    "PostgreSQL JDBC driver"

download_jar \
    "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar" \
    "$SCRIPT_DIR/lib/hadoop-aws-3.3.4.jar" \
    "Hadoop AWS JAR"

download_jar \
    "https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar" \
    "$SCRIPT_DIR/lib/aws-java-sdk-bundle-1.12.262.jar" \
    "AWS SDK bundle"

echo ""
echo "Creating and starting containers..."
docker-compose up -d

echo ""
echo "Waiting for Hive Metastore to be ready..."
sleep 10

# Wait for metastore
for i in {1..30}; do
    if docker-compose logs hive-metastore 2>&1 | grep -q "Starting Hive Metastore Server"; then
        echo "Hive Metastore is ready!"
        break
    fi
    echo "  Waiting... ($i/30)"
    sleep 2
done

echo ""
echo "Creating Spark notebook container..."
docker-compose -f spark-notebook.yml up -d

echo ""
echo "=========================================="
echo "Setup Complete! Lakehouse is running!"
echo "=========================================="
echo ""
echo "  Jupyter:      http://localhost:8888"
echo "  MinIO:        http://localhost:9001"
echo "  Spark UI:     http://localhost:4040 (when running queries)"
echo ""
echo "  MinIO login:  minioadmin / minioadmin"
echo ""
echo "Open the getting_started.ipynb notebook to begin."
echo ""
echo "Daily usage:"
echo "  ./stop.sh   - Stop containers (end of day)"
echo "  ./start.sh  - Start containers (next day)"
echo "  ./nuke.sh   - Delete everything and start fresh"
echo ""
