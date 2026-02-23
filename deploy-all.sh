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
echo "⚡ Triggering immediate first sync (then scheduler continues every 30 minutes)..."
BOOTSTRAP_ENV_FILE="functions/.env"
BOOTSTRAP_KEY=""

if [[ -f "$BOOTSTRAP_ENV_FILE" ]]; then
  BOOTSTRAP_KEY=$(grep -E '^SYNC_BOOTSTRAP_KEY=' "$BOOTSTRAP_ENV_FILE" | head -n1 | cut -d'=' -f2- | tr -d '"' | tr -d "'" || true)
fi

if [[ -z "${BOOTSTRAP_KEY:-}" ]]; then
  echo "⚠️  SYNC_BOOTSTRAP_KEY not found in functions/.env"
  echo "    Add SYNC_BOOTSTRAP_KEY=<long-random-secret> and redeploy to auto-run first sync."
else
  BOOTSTRAP_URL="https://us-central1-the-knb-app.cloudfunctions.net/runInitialCalendarSync"
  ATTEMPT=1
  until [[ $ATTEMPT -gt 3 ]]; do
    if curl --fail --silent --show-error --max-time 90 \
      -X POST \
      -H "x-sync-bootstrap-key: ${BOOTSTRAP_KEY}" \
      "$BOOTSTRAP_URL"; then
      echo ""
      echo "✅ Immediate first sync triggered successfully"
      break
    fi

    if [[ $ATTEMPT -eq 3 ]]; then
      echo "⚠️  Could not trigger immediate sync automatically."
      echo "    Retry manually with:"
      echo "    curl -X POST -H 'x-sync-bootstrap-key: <SYNC_BOOTSTRAP_KEY>' ${BOOTSTRAP_URL}"
      break
    fi

    ATTEMPT=$((ATTEMPT + 1))
    echo "⏳ Initial sync trigger failed, retrying in 5s (attempt ${ATTEMPT}/3)..."
    sleep 5
  done
fi

echo ""
echo "✅ Full backend deploy complete"
