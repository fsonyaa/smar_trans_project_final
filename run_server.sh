#!/bin/bash
# Start SmartTrans API Server locally
cd "$(dirname "$0")"

echo "========================================="
echo " SmartTrans API Server"
echo "========================================="
echo ""
echo "Local IP: 172.30.106.55"
echo "Port: 8000"
echo "Base URL: http://172.30.106.55:8000"
echo ""
echo "Test Credentials:"
echo "  test@local / test123 (client)"
echo "  admin@local / admin123 (admin)"
echo "  driver@local / driver123 (chauffeur)"
echo ""
echo "Commands:"
echo "  curl http://172.30.106.55:8000/test"
echo "  curl -X POST http://172.30.106.55:8000/login \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"email\":\"test@local\",\"password\":\"test123\"}'"
echo ""
echo "========================================="
echo "Starting server..."
echo "Press CTRL+C to stop"
echo ""

python app.py
