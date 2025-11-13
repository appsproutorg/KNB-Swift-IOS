# Running the iOS Simulator

## 🚀 Quick Start

### One-Time Setup (Required First Time Only)

Open **Terminal** and run:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

Enter your Mac password when prompted.

---

## 📱 Running the App

### Option 1: Using the Script (Easy!)

**From Terminal:**
```bash
cd /Users/ethangoizman/Downloads/Apps/IOS/KNB
./run-simulator.sh
```

**From Cursor Terminal:**
Just run the same command in the integrated terminal!

---

### Option 2: Using Xcode (Easiest!)

1. Open `The KNB App.xcodeproj` in Xcode
2. Select a simulator at the top (e.g., "iPhone 15 Pro")
3. Press **Cmd+R** or click the ▶️ Play button

---

### Option 3: Manual Command Line

```bash
cd /Users/ethangoizman/Downloads/Apps/IOS/KNB

# Open Simulator
open -a Simulator

# Build and run
xcodebuild -scheme "The KNB App" \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  clean build
```

---

## 🎯 Available Simulators

To see all available devices:

```bash
xcrun simctl list devices available
```

Common options:
- iPhone 15 Pro
- iPhone 15 Pro Max
- iPhone 14 Pro
- iPhone SE (3rd generation)
- iPad Pro (12.9-inch)

---

## 🔧 Troubleshooting

### "xcodebuild not found" or "tool requires Xcode"

**Fix:**
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

### "No scheme named 'The KNB App'"

**Fix:**
Check the scheme name in Xcode (Product → Scheme → Edit Scheme)

### Simulator won't open

**Fix:**
```bash
# Kill simulator process
killall Simulator

# Try again
open -a Simulator
```

### Build errors

1. Clean build folder in Xcode: **Cmd+Shift+K**
2. Or via terminal:
   ```bash
   xcodebuild clean -scheme "The KNB App"
   ```

---

## ⚡ Pro Tips

### Change Target Device

Edit `run-simulator.sh` and change this line:
```bash
DESTINATION="platform=iOS Simulator,name=iPhone 15 Pro"
```

To any simulator you want:
```bash
DESTINATION="platform=iOS Simulator,name=iPhone SE (3rd generation)"
```

### Faster Builds

Keep the Simulator app open between builds - it's faster!

### Multiple Simulators

You can run multiple simulators at once:
```bash
open -a Simulator --args -CurrentDeviceUDID <device-uuid>
```

Get device UUIDs:
```bash
xcrun simctl list devices
```

---

## 📝 Quick Reference

```bash
# Setup (one-time)
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

# Run app
./run-simulator.sh

# List devices
xcrun simctl list devices

# Open specific simulator
open -a Simulator

# Clean build
xcodebuild clean -scheme "The KNB App"

# View logs
xcrun simctl spawn booted log stream --predicate 'processImagePath endswith "KNB"'
```

---

## 🎨 Customizing the Script

The script is located at: `run-simulator.sh`

You can modify:
- Target device (line 33)
- Build configuration (Debug/Release)
- Additional build flags
- Output formatting

Just edit with any text editor!

