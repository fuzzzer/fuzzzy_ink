// The analyzer sees no `--flavor`, so it reads the macOS options as defaults.
// ignore_for_file: avoid_redundant_argument_values, use_named_constants

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const fuzzIdentificator = 'Fuzz/';
const fuzzedFileIdentificator = 'fuzz';

/// The keychain service every item of this app is kept under. The plugin's
/// default (`flutter_secure_storage_service`) is shared by every app that
/// uses it: in the macOS login keychain (development builds, below) "erase
/// everything" then also matched other apps' items and items an earlier
/// build left behind, which this build may not delete, so the first run
/// could never finish (QA 2026-10-26). Items under the old name are only
/// looked at as leftovers (`MasterKeyLocalDataSource.legacyNamespaceKeys`).
const secureStorageService = 'com.fuzzzycore.ink.keys';

/// Keychain items are `ThisDeviceOnly`: they never migrate through an
/// encrypted backup to another device (THREAT_MODEL §2.8 / D-8).
const secureStorageIosOptions = IOSOptions(
  accountName: secureStorageService,
  accessibility: KeychainAccessibility.unlocked_this_device,
);

/// Development builds are unsigned on macOS, so they use the login keychain
/// instead of the data-protection keychain (DECISIONS 2026-09-12 / D-3);
/// revert to `usesDataProtectionKeychain: true` once an Apple Development cert lands.
const secureStorageMacOsOptions = MacOsOptions(
  accountName: secureStorageService,
  accessibility: KeychainAccessibility.unlocked_this_device,
  usesDataProtectionKeychain: appFlavor != 'development',
);

/// The same keychain as [secureStorageIosOptions] and
/// [secureStorageMacOsOptions] under the plugin's shared default service,
/// where builds before [secureStorageService] kept their items.
const legacySecureStorageIosOptions = IOSOptions(
  accessibility: KeychainAccessibility.unlocked_this_device,
);

/// See [legacySecureStorageIosOptions].
const legacySecureStorageMacOsOptions = MacOsOptions(
  accessibility: KeychainAccessibility.unlocked_this_device,
  usesDataProtectionKeychain: appFlavor != 'development',
);

/// The settings tile that benchmarks the file path exists in the development
/// flavor only; staging and production builds never carry it. Not tied to
/// `kDebugMode` on purpose: a debug build ships the crate's dev profile, so
/// only a `--profile`/`--release` development build measures the real core.
const isFileBenchmarkEnabled = appFlavor == 'development';

/// The example in every recovery-key field: the form the key is shown and
/// printed in (eight groups of four, dashes), so both fields agree.
const recoveryKeyHint = 'XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX';
