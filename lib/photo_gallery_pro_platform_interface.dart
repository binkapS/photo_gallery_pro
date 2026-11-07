import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'photo_gallery_pro_method_channel.dart';
import 'src/album.dart';
import 'src/media.dart';
import 'src/media_type.dart';
import 'src/page_request.dart';
import 'src/permission_status.dart';
import 'src/thumbnail.dart';

/// The federated platform interface for `photo_gallery_pro`.
///
/// Platform implementations register themselves via
/// [PhotoGalleryProPlatform.instance]. All gallery operations route through
/// this interface; [PhotoGalleryPro] is a thin delegating facade and never
/// touches a `MethodChannel` itself, which keeps the facade unit-testable
/// against fakes.
abstract class PhotoGalleryProPlatform extends PlatformInterface {
  /// Constructs a [PhotoGalleryProPlatform].
  PhotoGalleryProPlatform() : super(token: _token);

  static final Object _token = Object();

  static PhotoGalleryProPlatform _instance = MethodChannelPhotoGalleryPro();

  /// The default instance of [PhotoGalleryProPlatform] to use.
  ///
  /// Defaults to [MethodChannelPhotoGalleryPro].
  static PhotoGalleryProPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [PhotoGalleryProPlatform] when
  /// they register themselves.
  static set instance(PhotoGalleryProPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Returns a display/debug string for the platform version, if available.
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Fetches all albums from the device gallery.
  ///
  /// When [type] is `null`, albums of every kind are returned (equivalent
  /// to [MediaType.mixed]). [page] windows the result set.
  Future<List<Album>> getAlbums({MediaType? type, PageRequest? page}) {
    throw UnimplementedError('getAlbums() has not been implemented.');
  }

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
  }) {
    throw UnimplementedError('getMediaInAlbum() has not been implemented.');
  }

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
    throw UnimplementedError('getThumbnail() has not been implemented.');
  }

  /// Fetches the representative (most recent) thumbnail for an album.
  Future<Thumbnail> getAlbumThumbnail(
    String albumId, {
    MediaType type = MediaType.mixed,
    ThumbnailSize size = const ThumbnailSize.square(512),
    ThumbnailFormat format = ThumbnailFormat.jpeg,
  }) {
    throw UnimplementedError('getAlbumThumbnail() has not been implemented.');
  }

  /// Fetches thumbnails for several media items in one call.
  ///
  /// Per-item failures (e.g. a file that vanished) are simply absent from
  /// the returned map; they do not fail the whole batch.
  Future<Map<String, Thumbnail>> getThumbnailBatch(
    List<String> mediaIds, {
    ThumbnailSize size = const ThumbnailSize.square(256),
    ThumbnailFormat format = ThumbnailFormat.jpeg,
  }) {
    throw UnimplementedError('getThumbnailBatch() has not been implemented.');
  }

  /// Loads the original (full-resolution) bytes of a media item.
  ///
  /// May trigger a cloud download (e.g. iCloud); call only from a
  /// user-initiated action and warn about the data budget.
  Future<Uint8List> getOriginalBytes(String mediaId) {
    throw UnimplementedError('getOriginalBytes() has not been implemented.');
  }

  /// Returns the current gallery [PermissionStatus].
  Future<PermissionStatus> getPermissionStatus() {
    throw UnimplementedError('getPermissionStatus() has not been implemented.');
  }

  /// Shows the system permission prompt and returns the resulting status.
  Future<PermissionStatus> requestPermission() {
    throw UnimplementedError('requestPermission() has not been implemented.');
  }

  /// Whether the gallery can be read (granted or limited access).
  Future<bool> hasPermission() async {
    final status = await getPermissionStatus();
    return status.canReadMedia;
  }
}
