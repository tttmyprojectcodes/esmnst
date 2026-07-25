#!/bin/bash
set -e

echo "Installing Flutter in user space..."
cd /tmp
git clone --depth 1 https://github.com/flutter/flutter.git -b stable
export PATH="/tmp/flutter/bin:$PATH"

# ✅ Navigate to the actual project directory
cd /opt/build/repo

echo "📁 Current directory: $(pwd)"
echo "📁 Listing files:"
ls -la

# ✅ Find frontend directory
if [ -d "frontend" ]; then
    echo "✅ Found frontend directory, navigating..."
    cd frontend
else
    echo "❌ Could not find frontend directory"
    exit 1
fi

echo "📦 Getting dependencies..."
flutter pub get

echo "🌐 Building web app with environment variables..."
flutter build web --release \
  --dart-define=API_URL="$API_URL" \
  --dart-define=FIREBASE_API_KEY="$FIREBASE_API_KEY" \
  --dart-define=FIREBASE_AUTH_DOMAIN="$FIREBASE_AUTH_DOMAIN" \
  --dart-define=FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
  --dart-define=FIREBASE_STORAGE_BUCKET="$FIREBASE_STORAGE_BUCKET" \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="$FIREBASE_MESSAGING_SENDER_ID" \
  --dart-define=FIREBASE_APP_ID="$FIREBASE_APP_ID"

# ✅ Copy assets to build/web
echo "📁 Copying assets to build/web..."
mkdir -p build/web/assets/images
cp -r assets/images/* build/web/assets/images/ 2>/dev/null || true

# Verify assets were copied
echo "Assets in build/web/assets/images:"
ls -la build/web/assets/images/ || echo "No assets found!"

echo "✅ Build complete! Files are in build/web"
