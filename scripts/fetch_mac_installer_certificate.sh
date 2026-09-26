#!/usr/bin/env bash
#
# Makes a Mac Installer Distribution certificate available to `keychain add-certificates`, which
# reads the .p12 files the `app-store-connect` tools save.
#
# `app-store-connect certificates list` prints "did not find any" and exits 0 on an empty result,
# so an `||` fallback would never fire. Success is measured by whether a file actually landed on
# disk, counted before and after because the Mac App Store fetch that runs first has already saved
# its own certificate into the same directory. Older tool versions save to MobileDevice/Certificates,
# newer ones to Xcode/UserData/Certificates, so both are counted.

set -euo pipefail

cert_dirs=(
  "$HOME/Library/MobileDevice/Certificates"
  "$HOME/Library/Developer/Xcode/UserData/Certificates"
)
mkdir -p "${cert_dirs[@]}"

count_certificates() {
  find "${cert_dirs[@]}" -name '*.p12' | wc -l | tr -d ' '
}

before=$(count_certificates)
app-store-connect certificates list --type MAC_INSTALLER_DISTRIBUTION --save
after=$(count_certificates)

if [ "$after" -eq "$before" ]; then
  echo "No Mac Installer Distribution certificate was saved — creating one."
  app-store-connect certificates create --type MAC_INSTALLER_DISTRIBUTION --save
  after=$(count_certificates)
fi

if [ "$after" -eq "$before" ]; then
  echo "ERROR: neither listing nor creating produced a Mac Installer Distribution certificate."
  exit 1
fi

find "${cert_dirs[@]}" -name '*.p12' -print
