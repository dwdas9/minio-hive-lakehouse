#!/bin/bash
# START - Starts existing stopped containers
# Use this daily to resume work

echo "Starting containers..."

docker-compose start
docker-compose -f spark-notebook.yml start

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

