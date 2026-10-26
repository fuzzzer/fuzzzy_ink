#!/bin/sh
# "Lock from other apps" (experimental): adds the Services menu entries
# (Services-development.plist) to the built Info.plist, for the development
# flavour only. Staging and production builds leave the Info.plist untouched,
# and one that carries the experiment's flag (FUZZ_ANYWHERE=true among the
# Dart defines) fails here: the experiment is for the development flavour
# only (security review 2026-10-26).
set -eu
case "${CONFIGURATION}" in
  *-development) ;;
  *)
    for define in $(echo "${DART_DEFINES:-}" | tr ',' ' '); do
      if [ "$(echo "${define}" | base64 -d 2>/dev/null)" = "FUZZ_ANYWHERE=true" ]; then
        echo "error: FUZZ_ANYWHERE=true is for the development flavour only; build ${CONFIGURATION} without it." >&2
        exit 1
      fi
    done
    exit 0 ;;
esac
plist="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
services="${SRCROOT}/Runner/Anywhere/Services-development.plist"
/usr/libexec/PlistBuddy -c "Delete :NSServices" "${plist}" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Add :NSServices array" "${plist}"
/usr/libexec/PlistBuddy -c "Merge '${services}' :NSServices" "${plist}"
