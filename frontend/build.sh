#!/bin/bash
set -e

echo "Installing Flutter in user space..."

# Install Flutter in a writable directory
cd /tmp
git clone --depth 1 https://github.com/flutter/flutter.git -b stable
export PATH="/tmp/flutter/bin:$PATH"

# Verify Flutter installation
flutter --version

# Navigate back to frontend directory
cd /opt/render/project/src/frontend

echo "Getting dependencies..."
flutter pub get

echo "Building web app..."
flutter build web --release --dart-define=API_URL=https://esmnst-backend.onrender.com

echo "Build complete! Files are in build/web"
