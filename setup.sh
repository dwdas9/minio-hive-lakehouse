#!/bin/bash
# Master setup script - Sets up both PART-A and optionally PART-B

echo "===================================================="
echo "  MinIO-Hive-Lakehouse Master Setup"
echo "===================================================="
echo ""

# Setup PART-A first
echo "Setting up PART-A (Core Infrastructure)..."
echo ""
cd PART-A && ./setup.sh
cd ..

echo ""
echo "═══════════════════════════════════════════════════"
echo ""
read -p "Do you want to setup PART-B (Learning Projects)? (y/n): " setup_b

if [ "$setup_b" = "y" ] || [ "$setup_b" = "Y" ]; then
    echo ""
    echo "Setting up PART-B (Streaming Analytics)..."
    echo ""
    cd PART-B && ./setup.sh
    cd ..
fi

echo ""
echo "===================================================="
echo "  Setup Complete!"
echo "===================================================="
echo ""
echo "Quick commands:"
echo "  cd PART-A && ./start.sh   - Start core lakehouse"
echo "  cd PART-A && ./stop.sh    - Stop core lakehouse"
echo "  cd PART-B && ./setup.sh   - Start learning projects"
echo ""
