#!/bin/bash
# Stop the Hive-Iceberg-MinIO Lakehouse

echo "Stopping Jupyter notebook..."
docker-compose -f spark-notebook.yml stop

echo "Stopping infrastructure..."
docker-compose stop

echo ""
echo "=========================================="
echo "Lakehouse stopped."
echo "=========================================="
echo ""
echo "Containers are stopped but preserved."
echo "Run ./start.sh to start again quickly."
echo ""
echo "To remove containers completely, run:"
echo "  ./nuke.sh"
echo ""
