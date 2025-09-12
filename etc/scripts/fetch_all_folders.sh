#!/bin/bash

# Define the target directory (default to current if not passed)
TARGET_DIR="${1:-.}"

# Check if the target is a directory
if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Error: '$TARGET_DIR' is not a directory."
  exit 1
fi

echo "Fetching all folders inside: $TARGET_DIR"

# Loop through all directories in the target directory
for dir in "$TARGET_DIR"/*/; do
  if [[ -d "$dir" ]]; then
    echo "Found folder: $dir"
    # Add your custom actions here (e.g., copy, compress, git pull, etc.)
    git -C "$dir" pull --rebase || {
      echo "Failed to pull changes in $dir"
      continue
    }
  fi
done
