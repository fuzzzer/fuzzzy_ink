import 'package:flutter/material.dart';

/// Which quick unlock the device has, so the words match it: "Face ID" on an
/// iPhone with Face ID, never "fingerprint" (final regression 2026-10-26).
enum BiometricKind {
  /// iPhone or iPad with Face ID.
  faceId,

  /// iPhone, iPad or Mac with Touch ID.
  touchId,

  /// Android with a fingerprint reader only.
  fingerprint,

  /// Android with face unlock only.
  face,

  /// Not known, or more than one kind (an Android phone with both, Windows
  /// Hello): the words say "fingerprint or face".
  other;

  /// The device's answer (`faceId`, `touchId`, `fingerprint`, `face`); any
  /// other answer, or none, is [other].
  static BiometricKind fromName(String? name) => values.firstWhere(
        (kind) => kind.name == name,
        orElse: () => other,
      );

  /// The value the strings' `{kind, select, …}` choose by.
  String get l10nKey => name;

  IconData get icon => switch (this) {
        faceId || face => Icons.face_unlock_outlined,
        touchId || fingerprint || other => Icons.fingerprint,
      };
}
