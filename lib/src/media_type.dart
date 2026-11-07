/// The kind of media handled by [PhotoGalleryPro].
///
/// [mixed] aggregates images and videos together; it is the default filter
/// for album and media queries so that mixed albums (e.g. a Camera Roll)
/// are enumerated in a single call.
enum MediaType {
  /// Images only (JPEG, PNG, HEIC, ...).
  image,

  /// Videos only (MP4, MOV, MKV, ...).
  video,

  /// Both images and videos.
  mixed,
}

/// Extensions for [MediaType] string parsing and serialization.
extension MediaTypeX on MediaType {
  /// Parses a platform-provided type string.
  ///
  /// Accepts `'image'`, `'video'`, and `'mixed'` (case-insensitive).
  /// Throws a [FormatException] for any unknown value so that payload/schema
  /// drift fails loudly instead of being silently mapped to a wrong type.
  static MediaType fromString(String value) {
    return switch (value.toLowerCase()) {
      'image' => MediaType.image,
      'video' => MediaType.video,
      'mixed' => MediaType.mixed,
      _ => throw FormatException('Unknown media type: $value'),
    };
  }
}
