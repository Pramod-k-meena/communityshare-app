#!/bin/bash

# This script will guide you through the process of removing sensitive information from your Git history
# It uses the BFG Repo-Cleaner tool which needs to be installed separately

echo "=====================================================================
REMOVING SENSITIVE INFORMATION FROM GIT HISTORY
=====================================================================
"

# Check if BFG is installed
if ! command -v bfg &> /dev/null; then
  echo "BFG Repo-Cleaner is not installed. You need to install it first."
  echo "For macOS: brew install bfg"
  echo "Or download from: https://rtyley.github.io/bfg-repo-cleaner/"
  exit 1
fi

echo "BFG Repo-Cleaner found!"

# Create a file with patterns to be replaced
cat << EOF > sensitive-patterns.txt
AIzaSyAINPzGAKqhAFtpNkfcAf7wr_k7acD11q0
AIzaSyBbIoXsCyU4CjUYOQKnJMVpD3k3tW3XWog
AIzaSyDRoA7_bfKpppPGBJ81AKMfuKouC8vsyRA
1:577535068852:web:359cd68415c3d832eb25e1
1:577535068852:android:fdf0225d8fcbf3b8eb25e1
1:577535068852:ios:4b0d6964f763a2c5eb25e1
1:577535068852:web:d16ccba677271281eb25e1
revive-and-thrive-1d7e4
577535068852
29295749346-quvsds271v3d0ahr41g3r5013dgt3qiv.apps.googleusercontent.com
EOF

echo "Created sensitive patterns file."
echo "Starting the BFG cleaning process..."

# Create a backup of the repository
cp -R .git .git.bak
echo "Backup of repository created at .git.bak"

# Run BFG to replace sensitive data
bfg --replace-text sensitive-patterns.txt

# Clean up
echo "
BFG replacement completed. Now we need to remove the sensitive data completely."
echo "Running git reflog expire and git gc..."

git reflog expire --expire=now --all
git gc --prune=now --aggressive

echo "
=====================================================================
CLEANING COMPLETED!
=====================================================================

Your repository history should now be clean of the sensitive API keys.
Next steps:

1. Force push to all branches:
   git push --force origin --all

2. Force push tags as well:
   git push --force origin --tags

IMPORTANT: This does not affect any clones others may have of your repository.
Anyone who has cloned your repo before this cleaning should re-clone it.

The sensitive-patterns.txt file has been created in your current directory.
You may want to delete it now:
   rm sensitive-patterns.txt
"

# Clean up the patterns file
rm sensitive-patterns.txt
