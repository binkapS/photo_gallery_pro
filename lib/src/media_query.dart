import 'media.dart';

/// A filter for `PhotoGalleryPro.searchMedia` queries.
///
/// All set constraints are AND-ed; unset constraints match anything.
class MediaQuery {
  /// Creates a [MediaQuery].
  const MediaQuery({
    this.nameContains,
    this.dateFrom,
    this.dateTo,
    this.minWidth,
    this.minHeight,
    this.mimeTypes,
    this.minDuration,
  });

  /// Case-insensitive substring match on the file name.
  final String? nameContains;

  /// Only media added at or after this time.
  final DateTime? dateFrom;

  /// Only media added at or before this time.
  final DateTime? dateTo;

  /// Minimum pixel width.
  final int? minWidth;

  /// Minimum pixel height.
  final int? minHeight;

  /// Allowed MIME types (e.g. `{'image/jpeg', 'image/png'}`).
  ///
  /// Media with an unknown [Media.mimeType] only match when this set is
  /// `null`.
  final Set<String>? mimeTypes;

  /// Minimum video duration (videos only).
  final Duration? minDuration;
}

/// Tests whether a media item matches every set constraint in this query.
extension MediaQueryMatcher on MediaQuery {
  /// Evaluates [media] against this query.
  bool matches(Media media) {
    if (nameContains != null &&
        !media.name.toLowerCase().contains(nameContains!.toLowerCase())) {
      return false;
    }
    if (dateFrom != null && media.dateAdded.isBefore(dateFrom!)) return false;
    if (dateTo != null && media.dateAdded.isAfter(dateTo!)) return false;
    if (minWidth != null && media.width < minWidth!) return false;
    if (minHeight != null && media.height < minHeight!) return false;
    if (mimeTypes != null) {
      final String? mime = media.mimeType;
      if (mime == null || !mimeTypes!.contains(mime)) return false;
    }
    if (minDuration != null) {
      if (media is! VideoMedia || media.duration < minDuration!) return false;
    }
    return true;
  }
}
