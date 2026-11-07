/// The effective permission state of the device media gallery.
///
/// The platform-native permission model differs per OS (Android
/// `READ_MEDIA_IMAGES`/`READ_MEDIA_VIDEO` grants, iOS authorized/limited),
/// which this enum normalizes into one cross-platform vocabulary.
enum PermissionStatus {
  /// Full access to photos and videos.
  granted,

  /// The user has not yet been asked.
  notDetermined,

  /// The user denied access (the system dialog can be shown again).
  denied,

  /// Access was denied permanently; the user must enable it in Settings.
  permanentlyDenied,

  /// Limited photo-library access (iOS / Android 14+ partial access):
  /// only the media the user explicitly selected is visible.
  limited,

  /// Platform-restricted access (e.g. parental controls).
  restricted,
}

/// Extensions for [PermissionStatus] string parsing.
extension PermissionStatusX on PermissionStatus {
  /// Parses a platform-provided status string.
  ///
  /// Accepts `'granted'`, `'notDetermined'`, `'denied'`,
  /// `'permanentlyDenied'`, `'limited'`, and `'restricted'`
  /// (case-insensitive). Throws a [FormatException] on unknown values.
  static PermissionStatus fromString(String value) {
    return switch (value.toLowerCase()) {
      'granted' || 'authorized' => PermissionStatus.granted,
      'notdetermined' || 'undetermined' => PermissionStatus.notDetermined,
      'denied' => PermissionStatus.denied,
      'permanentlydenied' => PermissionStatus.permanentlyDenied,
      'limited' => PermissionStatus.limited,
      'restricted' => PermissionStatus.restricted,
      _ => throw FormatException('Unknown permission status: $value'),
    };
  }

  /// Whether gallery media can be read under this status.
  ///
  /// Returns `true` for [PermissionStatus.granted] and
  /// [PermissionStatus.limited].
  bool get canReadMedia =>
      this == PermissionStatus.granted || this == PermissionStatus.limited;
}
