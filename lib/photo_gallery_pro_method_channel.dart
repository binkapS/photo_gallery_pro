import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'photo_gallery_pro_platform_interface.dart';
import 'src/album.dart';
import 'src/exceptions.dart';
import 'src/media.dart';
import 'src/media_type.dart';
import 'src/page_request.dart';
import 'src/permission_status.dart';
import 'src/thumbnail.dart';

/// An implementation of [PhotoGalleryProPlatform] that uses method channels.
///
/// Implements the channel contract in `plan.md` Appendix B. All arguments
/// are `String`/`int`/`bool`/`null`; binary payloads are [Uint8List].
class MethodChannelPhotoGalleryPro extends PhotoGalleryProPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('photo_gallery_pro');

  @override
  Future<String?> getPlatformVersion() async {
    return methodChannel.invokeMethod<String>('getPlatformVersion');
  }

  @override
  Future<List<Album>> getAlbums({MediaType? type, PageRequest? page}) async {
    return _invoke<List<Album>>(
      'getAlbums',
      <String, dynamic>{
        if (type != null) 'mediaType': type.name,
        if (page != null) 'offset': page.offset,
        if (page?.limit != null) 'limit': page!.limit,
      },
      (raw) =>
          (raw as List<dynamic>)
              .cast<Map<dynamic, dynamic>>()
              .map((map) => Album.fromJson(Map<String, dynamic>.from(map)))
              .toList(),
    );
  }

  @override
  Future<List<Media>> getMediaInAlbum(
    String albumId, {
    MediaType type = MediaType.mixed,
    PageRequest? page,
    MediaSort sort = MediaSort.dateAddedDesc,
  }) async {
    return _invoke<List<Media>>(
      'getMediaInAlbum',
      <String, dynamic>{
        'albumId': albumId,
        'mediaType': type.name,
        'sort': sort.name,
        if (page != null) 'offset': page.offset,
        if (page?.limit != null) 'limit': page!.limit,
      },
      (raw) =>
          (raw as List<dynamic>)
              .cast<Map<dynamic, dynamic>>()
              .map((map) => Media.fromJson(Map<String, dynamic>.from(map)))
              .toList(),
    );
  }

  @override
  Future<Thumbnail> getThumbnail(
    String mediaId, {
    ThumbnailSize size = const ThumbnailSize.square(512),
    ThumbnailFormat format = ThumbnailFormat.jpeg,
    MediaType? type,
  }) async {
    return _invoke<Thumbnail>('getThumbnail', <String, dynamic>{
      'mediaId': mediaId,
      'width': size.width,
      'height': size.height,
      'format': format.name,
      if (type != null) 'mediaType': type.name,
    }, (raw) => Thumbnail.fromPlatformData(raw));
  }

  @override
  Future<Thumbnail> getAlbumThumbnail(
    String albumId, {
    MediaType type = MediaType.mixed,
    ThumbnailSize size = const ThumbnailSize.square(512),
    ThumbnailFormat format = ThumbnailFormat.jpeg,
  }) async {
    return _invoke<Thumbnail>('getAlbumThumbnail', <String, dynamic>{
      'albumId': albumId,
      'mediaType': type.name,
      'width': size.width,
      'height': size.height,
      'format': format.name,
    }, (raw) => Thumbnail.fromPlatformData(raw));
  }

  @override
  Future<Map<String, Thumbnail>> getThumbnailBatch(
    List<String> mediaIds, {
    ThumbnailSize size = const ThumbnailSize.square(256),
    ThumbnailFormat format = ThumbnailFormat.jpeg,
  }) async {
    return _invoke<Map<String, Thumbnail>>(
      'getThumbnailBatch',
      <String, dynamic>{
        'mediaIds': mediaIds,
        'width': size.width,
        'height': size.height,
        'format': format.name,
      },
      (raw) => Map<String, dynamic>.from(
        raw as Map,
      ).map((key, value) => MapEntry(key, Thumbnail.fromPlatformData(value))),
    );
  }

  @override
  Future<Uint8List> getOriginalBytes(String mediaId) async {
    return _invoke<Uint8List>('getOriginalBytes', <String, dynamic>{
      'mediaId': mediaId,
    }, (raw) => _toUint8List(raw));
  }

  @override
  Future<PermissionStatus> getPermissionStatus() async {
    return _invoke<PermissionStatus>(
      'getPermissionStatus',
      const <String, dynamic>{},
      (raw) => PermissionStatusX.fromString(raw.toString()),
    );
  }

  @override
  Future<PermissionStatus> requestPermission() async {
    return _invoke<PermissionStatus>(
      'requestPermission',
      const <String, dynamic>{},
      (raw) => PermissionStatusX.fromString(raw.toString()),
    );
  }

  @override
  Future<bool> hasPermission() async {
    // Cheap local check via the status method; the native `hasPermission`
    // channel call is kept only for backward-compatible tooling.
    final status = await getPermissionStatus();
    return status.canReadMedia;
  }

  /// Invokes a channel method, parsing the raw result with [parse] and
  /// translating [PlatformException]s into the typed exception hierarchy.
  Future<T> _invoke<T>(
    String method,
    Map<String, dynamic> args,
    T Function(dynamic raw) parse,
  ) async {
    try {
      final dynamic result = await methodChannel.invokeMethod(method, args);
      return parse(result);
    } on PlatformException catch (e) {
      throw PhotoGalleryException.fromCode(
        e.code,
        e.message ?? e.code,
        e.details,
      );
    }
  }
}

Uint8List _toUint8List(dynamic raw) {
  if (raw is Uint8List) return raw;
  if (raw is List<int>) return Uint8List.fromList(raw);
  if (raw is ByteData) return raw.buffer.asUint8List();
  throw FormatException('Expected byte data, got ${raw.runtimeType}');
}
