#!/bin/bash

# Full backend deploy for KNB App
# Deploys: Cloud Functions + Firestore rules/indexes + Storage rules

set -euo pipefail

echo "🚀 Starting full Firebase backend deploy..."
echo ""

echo "📋 Checking Firebase login status..."
if ! firebase projects:list >/dev/null 2>&1; then
  echo "❌ Not logged in to Firebase"
  echo "🔐 Run: firebase login"
  exit 1
fi

echo "✅ Logged in"
echo ""

echo "🎯 Using project: the-knb-app"
firebase use the-knb-app

echo ""
echo "📦 Deploying functions + firestore (rules/indexes) + storage rules..."
firebase deploy --only functions,firestore,storage

echo ""
echo "✅ Full backend deploy complete"
