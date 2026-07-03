#!/bin/bash

# Exit on error
set -e

echo "Installing Flutter..."
apt-get update && apt-get install -y curl unzip git

# Clone Flutter
git clone https://github.com/flutter/flutter.git -b stable /flutter
export PATH="/flutter/bin:$PATH"

# Verify Flutter installation
flutter --version

echo "Getting dependencies..."
flutter pub get

echo "Building web app..."
flutter build web --release --dart-define=API_URL=https://esmnst-backend.onrender.com

echo "Build complete! Files are in build/web"
