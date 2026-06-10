#!/bin/bash
# Build and run SmartTrans on mobile device

API_URL="http://172.30.106.55:8000"

echo "========================================="
echo "SmartTrans Mobile App Builder"
echo "========================================="
echo ""
echo "API URL: $API_URL"
echo ""

# Check if device is connected
if ! flutter devices | grep -q "device"; then
    echo "ERROR: No device connected!"
    echo "Please connect a mobile device via USB or start an emulator"
    exit 1
fi

echo "Building APK for Android..."
flutter build apk \
  --dart-define=SMARTTRANS_API_URL="$API_URL" \
  --release

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================="
    echo "APK built successfully!"
    echo "Path: build/app/outputs/apk/release/app-release.apk"
    echo ""
    echo "Run with:"
    echo "  flutter run --dart-define=SMARTTRANS_API_URL=\"$API_URL\""
    echo "========================================="
else
    echo "Build failed!"
    exit 1
fi
