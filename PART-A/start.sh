#!/bin/bash
# START - Starts the lakehouse (creates containers if needed)
# Use this daily to resume work or after machine restart

echo "Starting lakehouse..."
echo ""

# Start core infrastructure (creates if doesn't exist)
docker-compose up -d

echo "Waiting for services to be healthy..."
sleep 10

# Start Jupyter notebook
docker-compose -f spark-notebook.yml up -d

echo ""
echo "=========================================="
echo "Lakehouse is running!"
echo "=========================================="
echo ""
echo "  Jupyter:      http://localhost:8888"
echo "  MinIO:        http://localhost:9001"
echo "  Spark UI:     http://localhost:4040 (when running queries)"
echo ""
echo "  MinIO login:  minioadmin / minioadmin"
echo ""
echo "Tip: Run 'docker ps' to verify all containers are running"
echo ""

