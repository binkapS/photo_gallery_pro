import 'package:flutter/foundation.dart';

import 'photo_gallery_pro_platform_interface.dart';
import 'src/album.dart';
import 'src/exceptions.dart';
import 'src/media.dart';
import 'src/media_query.dart';
import 'src/media_type.dart';
import 'src/page_request.dart';
import 'src/permission_status.dart';
import 'src/thumbnail.dart';

export 'src/album.dart';
export 'src/exceptions.dart';
export 'src/media.dart';
export 'src/media_query.dart';
export 'src/media_type.dart';
export 'src/page_request.dart';
export 'src/permission_status.dart';
export 'src/thumbnail.dart';
export 'src/thumbnail_cache.dart';

/// The `photo_gallery_pro` plugin facade.
///
/// A thin delegate to [PhotoGalleryProPlatform.instance]; it never talks to
/// a `MethodChannel` directly, so tests can substitute a fake platform.
///
/// ```dart
/// final gallery = PhotoGalleryPro();
///
/// final status = await gallery.getPermissionStatus();
/// if (!status.canReadMedia) {
///   await gallery.requestPermission();
/// }
///
/// final albums = await gallery.getAlbums(type: MediaType.mixed);
/// final media = await gallery.getMediaInAlbum(
///   albums.first.id,
///   type: MediaType.mixed,
///   page: PageRequest(limit: 100),
/// );
/// final thumb = await gallery.getThumbnail(
///   media.first.id,
///   size: const ThumbnailSize.square(256),
/// );
/// ```
///
/// Failures surface as typed [PhotoGalleryException]s (see `src/exceptions.dart`).
class PhotoGalleryPro {
  /// Returns a display/debug string for the platform version, if available.
  Future<String?> getPlatformVersion() =>
      PhotoGalleryProPlatform.instance.getPlatformVersion();

  /// Fetches all albums from the device gallery.
  ///
  /// When [type] is `null`, albums of every kind are returned (equivalent
  /// to [MediaType.mixed]). [page] windows the result set.
  Future<List<Album>> getAlbums({MediaType? type, PageRequest? page}) =>
      PhotoGalleryProPlatform.instance.getAlbums(type: type, page: page);

  /// Fetches media files in the album identified by [albumId].
  ///
  /// [type] defaults to [MediaType.mixed] so mixed albums enumerate in a
  /// single call. Results are sorted per [sort] (newest first by default)
  /// and windowed by [page].
  Future<List<Media>> getMediaInAlbum(
    String albumId, {
    MediaType type = MediaType.mixed,
    PageRequest? page,
    MediaSort sort = MediaSort.dateAddedDesc,
  }) => PhotoGalleryProPlatform.instance.getMediaInAlbum(
    albumId,
    type: type,
    page: page,
    sort: sort,
  );

  /// Fetches a thumbnail for the media item identified by [mediaId].
  ///
  /// [size] controls the requested pixel dimensions (default 512×512);
  /// [format] selects JPEG or PNG encoding. [type] may be provided when the
  /// platform needs it to locate the media; otherwise it is inferred.
  Future<Thumbnail> getThumbnail(
    String mediaId, {
    ThumbnailSize size = const ThumbnailSize.square(512),
    ThumbnailFormat format = ThumbnailFormat.jpeg,
    MediaType? type,
  }) {
    return PhotoGalleryProPlatform.instance
        .getThumbnail(mediaId, size: size, format: format, type: type)
        .catchError((Object error) {
          if (kDebugMode) {
            debugPrint('Error getting thumbnail: $error');
          }
          throw error;
        });
  }

  /// Fetches the representative (most recent) thumbnail for an album.
  Future<Thumbnail> getAlbumThumbnail(
    String albumId, {
    MediaType type = MediaType.mixed,
    ThumbnailSize size = const ThumbnailSize.square(512),
    ThumbnailFormat format = ThumbnailFormat.jpeg,
  }) => PhotoGalleryProPlatform.instance.getAlbumThumbnail(
    albumId,
    type: type,
    size: size,
    format: format,
  );

  /// Fetches thumbnails for several media items in one call.
  ///
  /// Per-item failures (e.g. a file that vanished) are simply absent from
  /// the returned map; they do not fail the whole batch.
  Future<Map<String, Thumbnail>> getThumbnailBatch(
    List<String> mediaIds, {
    ThumbnailSize size = const ThumbnailSize.square(256),
    ThumbnailFormat format = ThumbnailFormat.jpeg,
  }) => PhotoGalleryProPlatform.instance.getThumbnailBatch(
    mediaIds,
    size: size,
    format: format,
  );

  /// Loads the original (full-resolution) bytes of a media item.
  ///
  /// May trigger a cloud download (e.g. iCloud); call only from a
  /// user-initiated action and warn about the data budget.
  Future<Uint8List> getOriginalBytes(String mediaId) =>
      PhotoGalleryProPlatform.instance.getOriginalBytes(mediaId);

  /// Returns the current gallery [PermissionStatus].
  Future<PermissionStatus> getPermissionStatus() =>
      PhotoGalleryProPlatform.instance.getPermissionStatus();

  /// Shows the system permission prompt and returns the resulting status.
  ///
  /// This completes only after the system dialog resolves. Note the
  /// breaking change from `0.0.x`: this used to return `bool`; see
  /// `MIGRATION.md`.
  Future<PermissionStatus> requestPermission() =>
      PhotoGalleryProPlatform.instance.requestPermission();

  /// Whether the gallery can be read (granted or limited access).
  Future<bool> hasPermission() =>
      PhotoGalleryProPlatform.instance.hasPermission();

  /// Finds an album by its platform [id], or `null` if it no longer exists.
  Future<Album?> getAlbumById(String albumId) async {
    final List<Album> albums = await getAlbums();
    for (final Album album in albums) {
      if (album.id == albumId) return album;
    }
    return null;
  }

  /// Searches media in an album using a [MediaQuery] filter.
  ///
  /// This applies the requested [MediaType] and [sort] natively, then
  /// filters the result with [query] in Dart. For small galleries this
  /// avoids a native search API; native push-down can replace it later.
  Future<List<Media>> searchMedia(
    String albumId,
    MediaQuery query, {
    MediaType type = MediaType.mixed,
    PageRequest? page,
    MediaSort sort = MediaSort.dateAddedDesc,
  }) async {
    // Fetch without pagination so the filter sees every item; apply the
    // page window only after filtering, otherwise matches beyond the
    // first page would be silently missed.
    final List<Media> media = await getMediaInAlbum(
      albumId,
      type: type,
      sort: sort,
    );
    final List<Media> filtered = media.where(query.matches).toList();
    if (page == null) return filtered;
    final int start = page.offset.clamp(0, filtered.length);
    final int end =
        page.limit == null
            ? filtered.length
            : (start + page.limit!).clamp(start, filtered.length);
    return filtered.sublist(start, end);
  }

  /// Finds a media item by its platform [mediaId], or `null` if it no
  /// longer exists.
  ///
  /// Facade-only helper (like [getAlbumById]): it scans albums until the
  /// item is found, so prefer [getMediaInAlbum] when you already know the
  /// album. A native fast path may replace this later.
  Future<Media?> getMediaById(String mediaId) async {
    final List<Album> albums = await getAlbums();
    for (final Album album in albums) {
      final List<Media> media = await getMediaInAlbum(
        album.id,
        type: album.type,
      );
      for (final Media item in media) {
        if (item.id == mediaId) return item;
      }
    }
    return null;
  }
}
