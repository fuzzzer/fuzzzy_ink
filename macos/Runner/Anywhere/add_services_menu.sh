#!/bin/sh
# "Lock from other apps" (experimental): adds the Services menu entries
# (Services-development.plist) to the built Info.plist, for the development
# flavour only. Staging and production builds leave the Info.plist untouched.
set -eu
case "${CONFIGURATION}" in
  *-development) ;;
  *) exit 0 ;;
esac
plist="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
services="${SRCROOT}/Runner/Anywhere/Services-development.plist"
/usr/libexec/PlistBuddy -c "Delete :NSServices" "${plist}" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Add :NSServices array" "${plist}"
/usr/libexec/PlistBuddy -c "Merge '${services}' :NSServices" "${plist}"
