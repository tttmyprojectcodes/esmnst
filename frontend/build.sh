#!/bin/bash
set -e

echo "Installing Flutter in user space..."
cd /tmp
git clone --depth 1 https://github.com/flutter/flutter.git -b stable
export PATH="/tmp/flutter/bin:$PATH"

# Navigate back to frontend directory
cd /opt/render/project/src/frontend

echo "Getting dependencies..."
flutter pub get

echo "Building web app with environment variables..."
flutter build web --release \
  --dart-define=FIREBASE_API_KEY="$FIREBASE_API_KEY" \
  --dart-define=FIREBASE_AUTH_DOMAIN="$FIREBASE_AUTH_DOMAIN" \
  --dart-define=FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
  --dart-define=FIREBASE_STORAGE_BUCKET="$FIREBASE_STORAGE_BUCKET" \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="$FIREBASE_MESSAGING_SENDER_ID" \
  --dart-define=FIREBASE_APP_ID="$FIREBASE_APP_ID"

echo "Build complete! Files are in build/web"
