/// The ordering applied to media results in
/// [PhotoGalleryPro.getMediaInAlbum].
///
/// The sort is pushed down to the native layer where the platform supports
/// it. The default is [MediaSort.dateAddedDesc] (newest first).
enum MediaSort {
  /// Newest first (the default).
  dateAddedDesc,

  /// Oldest first.
  dateAddedAsc,

  /// Alphabetical by file name, ascending.
  nameAsc,

  /// Largest file size first.
  sizeDesc,
}

/// A page window into a larger result set.
///
/// Both `offset` and `limit` are forwarded to the platform so that large
/// galleries never need to be fully materialized.
///
/// ```dart
/// final firstPage = await gallery.getMediaInAlbum(
///   album.id,
///   page: PageRequest(offset: 0, limit: 100),
/// );
/// ```
class PageRequest {
  /// Zero-based index of the first item to return.
  final int offset;

  /// Maximum number of items to return. `null` means "no limit".
  final int? limit;

  /// Creates a [PageRequest].
  const PageRequest({this.offset = 0, this.limit});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PageRequest && offset == other.offset && limit == other.limit;

  @override
  int get hashCode => Object.hash(offset, limit);

  @override
  String toString() => 'PageRequest(offset: $offset, limit: $limit)';
}
