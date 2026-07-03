#!/bin/bash

# Install Flutter if not installed
if ! command -v flutter &> /dev/null; then
    echo "Installing Flutter..."
    apt-get update && apt-get install -y curl unzip git
    git clone https://github.com/flutter/flutter.git -b stable /flutter
    export PATH="/flutter/bin:$PATH"
fi

# Navigate to frontend directory
cd frontend

# Get dependencies
echo "Getting dependencies..."
flutter pub get

# Build web app
echo "Building web app..."
flutter build web --release --dart-define=API_URL=https://esmnst-backend.onrender.com

echo "Build complete! Files are in frontend/build/web"
