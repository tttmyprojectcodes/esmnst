#!/bin/bash
# frontend/build.sh

# Install Flutter
echo "Installing Flutter..."
git clone https://github.com/flutter/flutter.git -b stable /flutter
export PATH="/flutter/bin:$PATH"

# Verify Flutter installation
flutter --version

# Get dependencies
echo "Getting dependencies..."
flutter pub get

# Build web app
echo "Building web app..."
flutter build web --release --dart-define=API_URL=https://esmnst-backend.onrender.com

# Create output directory
mkdir -p /opt/render/project/src/build
cp -r build/web/* /opt/render/project/src/build/

echo "Build complete!"
