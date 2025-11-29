#!/bin/bash
# NUKE - Complete destruction! Removes all containers, volumes, and data
# Use this when you want to start completely fresh

echo "=========================================="
echo "☢️  NUKE - Complete Cleanup"
echo "=========================================="
echo ""
echo "This will PERMANENTLY DELETE:"
echo "  • All containers"
echo "  • All data in MinIO (your files)"
echo "  • All data in PostgreSQL (your metastore)"
echo "  • All Iceberg tables and metadata"
echo ""
read -p "Are you sure? Type 'yes' to confirm: " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "Removing Spark notebook..."
docker-compose -f spark-notebook.yml down -v 2>/dev/null

echo "Removing infrastructure..."
docker-compose down -v

echo ""
echo "=========================================="
echo "✓ Everything has been nuked!"
echo "=========================================="
echo ""
echo "All containers and data removed."
echo "Run ./setup.sh to create fresh containers."
echo ""
