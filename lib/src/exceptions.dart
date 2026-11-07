/// Known gallery failure modes, surfaced as typed exceptions.
///
/// The platform layer maps each native error `code` (see `plan.md`
/// Appendix B) to one of these types so callers can react programmatically
/// instead of parsing strings:
///
/// ```dart
/// try {
///   await gallery.getThumbnail(media.id);
/// } on NotFoundException {
///   // The file vanished from the gallery; drop it from the UI.
/// }
/// ```
sealed class PhotoGalleryException implements Exception {
  /// Creates a [PhotoGalleryException].
  const PhotoGalleryException(this.code, this.message, [this.details]);

  /// Machine-readable error code from the platform
  /// (e.g. `PERMISSION_ERROR`, `NOT_FOUND`).
  final String code;

  /// Human-readable description of the failure.
  final String message;

  /// Optional platform-provided details.
  final Object? details;

  /// Maps a method-channel (or any platform) error code to a typed exception.
  factory PhotoGalleryException.fromCode(
    String code,
    String message, [
    Object? details,
  ]) {
    return switch (code) {
      'PERMISSION_ERROR' => PermissionDeniedException(message, details),
      'NOT_FOUND' => NotFoundException(message, details),
      'INVALID_TYPE' => UnsupportedMediaTypeException(message, details),
      'THUMBNAIL_ERROR' => ThumbnailException(message, details),
      _ => PlatformGalleryException(code, message, details),
    };
  }

  @override
  String toString() => '$runtimeType($code): $message';
}

/// The user has not granted (or has revoked) gallery permission.
class PermissionDeniedException extends PhotoGalleryException {
  /// Creates a [PermissionDeniedException].
  const PermissionDeniedException([
    String message = 'Permission denied',
    Object? details,
  ]) : super('PERMISSION_ERROR', message, details);
}

/// The requested album or media item no longer exists.
class NotFoundException extends PhotoGalleryException {
  /// Creates a [NotFoundException].
  const NotFoundException([String message = 'Not found', Object? details])
    : super('NOT_FOUND', message, details);
}

/// The platform or caller requested a media type that is not supported.
class UnsupportedMediaTypeException extends PhotoGalleryException {
  /// Creates an [UnsupportedMediaTypeException].
  const UnsupportedMediaTypeException([
    String message = 'Unsupported media type',
    Object? details,
  ]) : super('INVALID_TYPE', message, details);
}

/// Thumbnail generation failed for the requested media item.
class ThumbnailException extends PhotoGalleryException {
  /// Creates a [ThumbnailException].
  const ThumbnailException([
    String message = 'Thumbnail error',
    Object? details,
  ]) : super('THUMBNAIL_ERROR', message, details);
}

/// Any other gallery failure originating on the platform.
class PlatformGalleryException extends PhotoGalleryException {
  /// Creates a [PlatformGalleryException].
  const PlatformGalleryException(super.code, super.message, [super.details]);
}
