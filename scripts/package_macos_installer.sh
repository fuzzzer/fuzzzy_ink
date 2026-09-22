#!/usr/bin/env bash
#
# Builds the installer package App Store Connect accepts and signs it with the Mac Installer
# Distribution certificate.
#
#   scripts/package_macos_installer.sh <products-dir> <product-name>
#
# The certificate is chosen by matching "Mac Developer Installer" inside its common name, which is
# a contract with Apple's console wording rather than an API guarantee — so anything other than
# exactly one match stops here instead of signing with whatever else is in the keychain.
#
# Deliberately no `head -n 1`: under `set -o pipefail` the closed pipe can kill this with SIGPIPE
# for a reason that has nothing to do with certificates, and taking the first of several matches
# picks by sort order, which an expired certificate wins as easily as a valid one.

set -euo pipefail

products_dir=${1:?usage: package_macos_installer.sh <products-dir> <product-name>}
product_name=${2:?usage: package_macos_installer.sh <products-dir> <product-name>}

cd "$products_dir"

xcrun productbuild --component "$product_name.app" /Applications/ unsigned.pkg

installer_certificates=$(keychain list-certificates \
  | jq -r '[.[] | select(.common_name | contains("Mac Developer Installer")) | .common_name] | unique | .[]')
installer_certificate_count=$(printf '%s' "$installer_certificates" | grep -c . || true)

if [ "$installer_certificate_count" -ne 1 ]; then
  echo "ERROR: expected exactly one Mac Installer Distribution certificate in the keychain, found $installer_certificate_count."
  echo "Matched common names were:"
  printf '%s\n' "$installer_certificates"
  echo "Zero means no installer certificate was saved, or Apple changed the certificate's common"
  echo "name. More than one means the team holds several — possibly an expired one — and productsign"
  echo "must not be left to guess between them."
  exit 1
fi

xcrun productsign --sign "$installer_certificates" unsigned.pkg "$product_name.pkg"
rm -f unsigned.pkg
