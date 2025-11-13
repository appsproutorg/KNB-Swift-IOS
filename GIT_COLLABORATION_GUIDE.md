# Git Collaboration Guide - KNB Project

## 📦 Repository Information
- **Repository**: https://github.com/appsproutorg/KNB
- **Owner**: appsproutorg
- **Branch**: main

---

## 🚀 Initial Setup for Your Partner

### Step 1: Install Git (if not already installed)

**On Mac:**
```bash
# Check if git is installed
git --version

# If not installed, install Xcode Command Line Tools
xcode-select --install
```

### Step 2: Configure Git Identity
```bash
# Set your name (replace with actual name)
git config --global user.name "Your Name"

# Set your email (replace with actual email)
git config --global user.email "your.email@example.com"

# Verify configuration
git config --list
```

### Step 3: Clone the Repository

**Option A: Using HTTPS (Easier)**
```bash
# Navigate to where you want the project
cd ~/Downloads/Apps/IOS/

# Clone the repository
git clone https://github.com/appsproutorg/KNB.git

# Navigate into the project
cd KNB
```

**Option B: Using SSH (More Secure - Recommended)**
```bash
# First, set up SSH key (if you haven't)
ssh-keygen -t ed25519 -C "your.email@example.com"

# Copy the public key
cat ~/.ssh/id_ed25519.pub

# Add this key to GitHub:
# 1. Go to GitHub.com → Settings → SSH and GPG keys
# 2. Click "New SSH key"
# 3. Paste your public key

# Then clone using SSH
cd ~/Downloads/Apps/IOS/
git clone git@github.com:appsproutorg/KNB.git
cd KNB
```

### Step 4: Verify Setup
```bash
# Check remote connection
git remote -v

# Should show:
# origin  https://github.com/appsproutorg/KNB.git (fetch)
# origin  https://github.com/appsproutorg/KNB.git (push)

# Check current branch
git branch

# Should show:
# * main
```

---

## 👥 Daily Collaboration Workflow

### Before You Start Working (ALWAYS DO THIS!)

```bash
# 1. Make sure you're on main branch
git checkout main

# 2. Pull latest changes from GitHub
git pull origin main

# 3. Check status
git status
```

### While Working on a Feature

**Option 1: Work on Main Branch (Simple - Good for Small Team)**
```bash
# 1. Pull latest changes
git pull origin main

# 2. Make your changes in Xcode
# ... code, code, code ...

# 3. Check what changed
git status

# 4. Stage your changes
git add .

# 5. Commit with a descriptive message
git commit -m "Add feature: description of what you did"

# 6. Push to GitHub
git push origin main
```

**Option 2: Work on Feature Branches (Better - Recommended)**
```bash
# 1. Create a new branch for your feature
git checkout -b feature/your-feature-name

# 2. Make your changes
# ... code, code, code ...

# 3. Stage and commit
git add .
git commit -m "Add feature: description"

# 4. Push your branch to GitHub
git push origin feature/your-feature-name

# 5. Create a Pull Request on GitHub
# Go to: https://github.com/appsproutorg/KNB/pulls
# Click "New Pull Request"
# Select your branch
# Request review from your partner

# 6. After approval, merge the PR on GitHub

# 7. Switch back to main and update
git checkout main
git pull origin main

# 8. Delete the feature branch (optional)
git branch -d feature/your-feature-name
```

---

## 🔧 Common Git Commands

### Checking Status
```bash
# See what files have changed
git status

# See detailed changes
git diff

# See commit history
git log --oneline -10

# See who changed what
git blame filename.swift
```

### Saving Your Work
```bash
# Stage specific files
git add KNB/SomeFile.swift

# Stage all changes
git add .

# Unstage a file
git restore --staged KNB/SomeFile.swift

# Commit staged changes
git commit -m "Your message here"

# Amend last commit (if you forgot something)
git commit --amend -m "Updated message"
```

### Syncing with GitHub
```bash
# Get latest changes (doesn't merge)
git fetch origin

# Get and merge latest changes
git pull origin main

# Push your changes
git push origin main

# Force push (USE WITH CAUTION!)
git push --force origin main
```

### Branch Management
```bash
# List all branches
git branch -a

# Create new branch
git checkout -b feature/new-feature

# Switch to existing branch
git checkout main

# Delete local branch
git branch -d feature/old-feature

# Delete remote branch
git push origin --delete feature/old-feature
```

---

## ⚠️ Handling Merge Conflicts

Conflicts happen when both people edit the same file. Here's how to resolve them:

### Step 1: Try to Pull
```bash
git pull origin main
```

If you see:
```
CONFLICT (content): Merge conflict in KNB/SomeFile.swift
Automatic merge failed; fix conflicts and then commit the result.
```

### Step 2: Open the Conflicted File

You'll see something like:
```swift
<<<<<<< HEAD
// Your changes
let message = "Hello"
=======
// Their changes
let message = "Hi there"
>>>>>>> origin/main
```

### Step 3: Resolve the Conflict

Edit the file to keep what you want:
```swift
// Resolved version
let message = "Hello"
```

### Step 4: Mark as Resolved
```bash
# Stage the resolved file
git add KNB/SomeFile.swift

# Commit the merge
git commit -m "Resolve merge conflict in SomeFile.swift"

# Push to GitHub
git push origin main
```

---

## 🎯 Best Practices for Collaboration

### 1. **Communicate**
- Tell your partner when you're working on a file
- Use meaningful commit messages
- Create GitHub Issues for tasks

### 2. **Pull Before You Push**
```bash
# ALWAYS do this before pushing
git pull origin main
git push origin main
```

### 3. **Commit Often**
- Make small, focused commits
- Don't wait until end of day
- Each commit should be one logical change

### 4. **Write Good Commit Messages**

❌ **Bad:**
```bash
git commit -m "fixed stuff"
git commit -m "update"
git commit -m "wip"
```

✅ **Good:**
```bash
git commit -m "Fix login button color in dark mode"
git commit -m "Add reset bids functionality to debug menu"
git commit -m "Update calendar to show sponsorship details"
```

### 5. **Use Branches for Big Features**
```bash
# Create feature branch
git checkout -b feature/new-auction-screen

# Work on it
git add .
git commit -m "Add auction screen UI"

# Push branch
git push origin feature/new-auction-screen

# Create Pull Request on GitHub
# After review and approval, merge
```

### 6. **Don't Commit These Files**
The `.gitignore` file already handles most of this, but avoid:
- ❌ `UserInterfaceState.xcuserstate` (Xcode user data)
- ❌ `.DS_Store` (Mac system files)
- ❌ Personal API keys or secrets
- ❌ Build artifacts

---

## 🚨 Emergency Commands

### Undo Last Commit (Keep Changes)
```bash
git reset --soft HEAD~1
```

### Undo Last Commit (Discard Changes)
```bash
git reset --hard HEAD~1
```

### Discard All Local Changes
```bash
# ⚠️ This will DELETE all your uncommitted work!
git reset --hard origin/main
```

### Stash Your Work (Save for Later)
```bash
# Save your work temporarily
git stash

# Do something else (like pull)
git pull origin main

# Get your work back
git stash pop
```

### See What Would Be Pulled
```bash
git fetch origin
git log HEAD..origin/main --oneline
```

---

## 📱 Xcode-Specific Tips

### When Opening Project
1. **Always pull first:**
   ```bash
   git pull origin main
   ```
2. Open `The KNB App.xcodeproj` (not .xcworkspace)

### When Xcode Changes Project File
The file `The KNB App.xcodeproj/project.pbxproj` often has conflicts:

```bash
# If conflict, try:
git checkout --theirs The\ KNB\ App.xcodeproj/project.pbxproj
git add .
git commit -m "Accept Xcode project changes"
```

### Before Committing
```bash
# Close Xcode (to avoid user state conflicts)
# Then commit:
git add .
git commit -m "Your message"
git push origin main
```

---

## 🔐 Access Management

### Give Your Partner Access to GitHub Repo

1. Go to: https://github.com/appsproutorg/KNB/settings/access
2. Click **"Add people"**
3. Enter their GitHub username or email
4. Choose permission level:
   - **Write**: Can push to repo ✅ (Recommended)
   - **Admin**: Can change settings
   - **Read**: Can only view

### They'll receive an email invitation
- Accept invitation
- Now they can push/pull

---

## 📊 Workflow Example

### Scenario: Both of you working on different features

**You (Ethan):**
```bash
git pull origin main
# Work on debug menu
git add .
git commit -m "Add admin role to debug menu"
git push origin main
```

**Your Partner:**
```bash
git pull origin main
# Work on calendar view
git add .
git commit -m "Improve calendar loading performance"
git push origin main
```

### Scenario: Both editing same file (potential conflict)

**You (Ethan):**
```bash
git pull origin main
# Edit CalendarView.swift - change color to blue
git add .
git commit -m "Change calendar background to blue"
git push origin main  # ✅ Success
```

**Your Partner:**
```bash
git pull origin main  # Gets your blue change
# Edit CalendarView.swift - add new function
git add .
git commit -m "Add calendar refresh function"
git push origin main  # ✅ Success (no conflict, different lines)
```

---

## 🆘 Getting Help

### If Something Goes Wrong

1. **Don't Panic!** Git rarely loses data
2. **Check status:**
   ```bash
   git status
   git log --oneline -5
   ```

3. **Ask for help in your commit:**
   ```bash
   git reflog  # Shows all actions, can recover anything
   ```

4. **Start fresh (last resort):**
   ```bash
   cd ..
   rm -rf KNB
   git clone https://github.com/appsproutorg/KNB.git
   ```

### Useful Resources
- GitHub Docs: https://docs.github.com
- Git Cheat Sheet: https://education.github.com/git-cheat-sheet-education.pdf
- Interactive Tutorial: https://learngitbranching.js.org/

---

## ✅ Quick Reference Card

```bash
# Daily workflow
git pull origin main          # Get latest
git add .                      # Stage changes
git commit -m "message"        # Commit
git push origin main           # Push to GitHub

# Check status
git status                     # What changed
git log --oneline -5           # Recent commits

# Branching
git checkout -b feature/name   # Create branch
git checkout main              # Switch to main
git branch -d feature/name     # Delete branch

# Emergency
git stash                      # Save work temporarily
git reset --hard origin/main   # Discard all local changes
```

---

## 🎉 You're All Set!

Both you and your partner can now:
- ✅ Pull latest changes
- ✅ Make commits
- ✅ Push to GitHub
- ✅ Collaborate without conflicts
- ✅ Review each other's code

**Pro Tip:** Set up a daily routine:
1. Morning: `git pull origin main`
2. Work on your feature
3. Before lunch: Commit and push
4. End of day: Commit and push
5. Communicate what you're working on!

Happy coding! 🚀

