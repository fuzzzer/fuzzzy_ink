#!/usr/bin/env bash
#
# Makes a Mac Installer Distribution certificate available to `keychain add-certificates`, which
# reads .p12 files out of $HOME/Library/MobileDevice/Certificates.
#
# `app-store-connect certificates list` prints "did not find any" and exits 0 on an empty result,
# so an `||` fallback would never fire. Success is measured by whether a file actually landed on
# disk, counted before and after because the Mac App Store fetch that runs first has already saved
# its own certificate into the same directory.

set -euo pipefail

cert_dir="$HOME/Library/MobileDevice/Certificates"
mkdir -p "$cert_dir"

count_certificates() {
  find "$cert_dir" -name '*.p12' | wc -l | tr -d ' '
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

find "$cert_dir" -name '*.p12' -print
