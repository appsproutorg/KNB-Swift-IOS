#!/bin/bash

# Deploy Everything Script for KNB App
# This will deploy Cloud Functions and Firestore Rules

echo "🚀 Starting deployment..."
echo ""

# Check if logged in
echo "📋 Checking Firebase login status..."
if ! firebase projects:list &>/dev/null; then
    echo "❌ Not logged in to Firebase"
    echo "🔐 Please run: firebase login"
    echo "   (This will open your browser for authentication)"
    exit 1
fi

echo "✅ Logged in to Firebase"
echo ""

# Set the project
echo "🎯 Setting Firebase project to: the-knb-app"
firebase use the-knb-app

echo ""
echo "📦 Deploying Cloud Functions..."
firebase deploy --only functions

echo ""
echo "📜 Deploying Firestore Rules..."
firebase deploy --only firestore:rules

echo ""
echo "✅ Deployment complete!"
echo ""
echo "🎉 Your push notifications are now set up!"
echo ""
echo "Next steps:"
echo "1. Test on your iPhone (not simulator!)"
echo "2. Log in to the app"
echo "3. Check Firestore for your FCM token"
echo "4. Test with Firebase Console → Cloud Messaging"

