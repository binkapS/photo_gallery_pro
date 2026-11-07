import 'thumbnail.dart';

/// An in-memory LRU cache for [Thumbnail]s.
///
/// Grid views that request one thumbnail per cell re-issue a method-channel
/// call on every rebuild without a cache; this class deduplicates and caps
/// memory use so scrolling a large album stays smooth.
///
/// ```dart
/// final cache = ThumbnailCache(maxEntries: 500, maxBytes: 20 << 20);
/// final thumb = await cache.getOrLoad(
///   media.id,
///   () => gallery.getThumbnail(media.id, size: const ThumbnailSize.square(256)),
/// );
/// ```
class ThumbnailCache {
  /// Creates a [ThumbnailCache].
  ///
  /// At most [maxEntries] thumbnails, and at most [maxBytes] bytes of pixel
  /// data, are retained; least-recently-used entries are evicted first.
  ThumbnailCache({this.maxEntries = 500, this.maxBytes = 20 << 20});

  /// Maximum number of cached thumbnails.
  final int maxEntries;

  /// Maximum total byte size of cached thumbnail data.
  final int maxBytes;

  // LinkedHashMap iteration order = insertion order; we re-insert on
  // access so the front of the map is always the least-recently-used entry.
  final Map<String, Thumbnail> _entries = <String, Thumbnail>{};
  int _bytes = 0;

  /// The number of thumbnails currently cached.
  int get length => _entries.length;

  /// The total byte size of cached thumbnail data.
  int get bytes => _bytes;

  /// Returns the cached thumbnail for [id], if present.
  ///
  /// The entry is marked as most-recently-used.
  Thumbnail? get(String id) {
    final thumbnail = _entries.remove(id);
    if (thumbnail == null) return null;
    _entries[id] = thumbnail;
    return thumbnail;
  }

  /// Returns the cached thumbnail for [id], loading it with [loader] first
  /// if it is not already cached.
  Future<Thumbnail> getOrLoad(
    String id,
    Future<Thumbnail> Function() loader,
  ) async {
    final cached = get(id);
    if (cached != null) return cached;
    final loaded = await loader();
    put(id, loaded);
    return loaded;
  }

  /// Inserts [thumbnail] under [id], evicting LRU entries until both
  /// [maxEntries] and [maxBytes] limits hold.
  void put(String id, Thumbnail thumbnail) {
    final previous = _entries.remove(id);
    if (previous != null) _bytes -= previous.data.length;
    _entries[id] = thumbnail;
    _bytes += thumbnail.data.length;
    while (_entries.length > maxEntries ||
        (_bytes > maxBytes && _entries.length > 1)) {
      final lruId = _entries.keys.first;
      _bytes -= _entries.remove(lruId)!.data.length;
    }
  }

  /// Whether the cache holds a thumbnail for [id].
  bool contains(String id) => _entries.containsKey(id);

  /// Drops all cached thumbnails.
  void clear() {
    _entries.clear();
    _bytes = 0;
  }
}
