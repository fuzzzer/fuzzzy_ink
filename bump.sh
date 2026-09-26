#!/bin/bash

if [[ -n "$1" ]]; then
    PROJECT_PATH="$1"
else
    PROJECT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Navigate to the project directory
cd "$PROJECT_PATH" || { echo "Path not found: $PROJECT_PATH"; exit 1; }

# Uncomment if we need to Ensure working tree is clean
# if [[ -n "$(git status --porcelain)" ]]; then
#     echo "❌ Working directory is not clean. Commit or stash first."
#     exit 1
# fi

# Ensure pubspec.yaml exists
if [[ ! -f "pubspec.yaml" ]]; then
    echo "pubspec.yaml not found in $PROJECT_PATH"
    exit 1
fi

# Extract the current version from pubspec.yaml
CURRENT_VERSION=$(grep -E '^version:' pubspec.yaml | awk '{print $2}')

# Check the version format
if [[ "$CURRENT_VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(\+([0-9]+))?$ ]]; then
    MAJOR="${BASH_REMATCH[1]}"
    MINOR="${BASH_REMATCH[2]}"
    PATCH="${BASH_REMATCH[3]}"
    BUILD="${BASH_REMATCH[5]}" # Optional build number

    # always bump patch; bump build if present
    NEW_PATCH=$((PATCH + 1))
    if [[ -n "$BUILD" ]]; then
        NEW_BUILD=$((BUILD + 1))
        NEW_VERSION="${MAJOR}.${MINOR}.${NEW_PATCH}+${NEW_BUILD}"
    else
        NEW_VERSION="${MAJOR}.${MINOR}.${NEW_PATCH}"
    fi
else
    echo "Error: Version format in pubspec.yaml is invalid"
    exit 1
fi

# Update the version in pubspec.yaml
sed -i.bak "s/^version: .*/version: ${NEW_VERSION}/" pubspec.yaml && rm pubspec.yaml.bak

git fetch

# If the remote branch (@{u}) is NOT an ancestor of HEAD (@), abort.
if ! git merge-base --is-ancestor @{u} @; then
  echo "❌ Remote branch is ahead (or has diverged). Pull/rebase first."
  exit 1
fi
echo "✅ Local branch is up to date or ahead. Continuing…"

git add pubspec.yaml
git commit -m "chore: bump version to ${NEW_VERSION}"
git tag "v${NEW_VERSION}" -m "Version ${NEW_VERSION} of the project"
git push
git push --tags

echo "Version updated to ${NEW_VERSION}, committed, and tagged successfully."
