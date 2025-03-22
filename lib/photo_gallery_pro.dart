import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'src/album.dart';
import 'src/media.dart';
import 'src/thumbnail.dart';
import 'photo_gallery_pro_platform_interface.dart';
import 'package:photo_gallery_pro/src/media_type.dart';

export 'src/album.dart';
export 'src/media.dart';
export 'src/thumbnail.dart';
export 'src/media_type.dart';

class PhotoGalleryPro {
  static const MethodChannel _channel = MethodChannel('photo_gallery_pro');

  Future<String?> getPlatformVersion() {
    return PhotoGalleryProPlatform.instance.getPlatformVersion();
  }

  /// Fetches all albums from the device
  Future<List<Album>> getAlbums() async {
    try {
      final List<dynamic> albums = await _channel.invokeMethod('getAlbums');
      if (kDebugMode) {
        print('Fetched ${albums.length} albums');
      }
      return albums
          .cast<Map<dynamic, dynamic>>()
          .map((map) => Album.fromJson(Map<String, dynamic>.from(map)))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching albums: $e');
      }
      rethrow;
    }
  }

  /// Fetches media files from a specific album
  Future<List<Media>> getMediaInAlbum(
    String albumId, {
    MediaType type = MediaType.image,
  }) async {
    final List<dynamic> mediaFiles = await _channel.invokeMethod(
      'getMediaInAlbum',
      {'albumId': albumId, 'mediaType': type.toString().split('.').last},
    );

    return mediaFiles
        .cast<Map<dynamic, dynamic>>()
        .map((map) => Media.fromJson(Map<String, dynamic>.from(map)))
        .toList();
  }

  /// Generates or fetches a thumbnail for a specific media item
  Future<Thumbnail> getThumbnail(
    String mediaId, {
    MediaType type = MediaType.image,
  }) async {
    try {
      final dynamic thumbnailData = await _channel.invokeMethod(
        'getThumbnail',
        {'mediaId': mediaId, 'mediaType': type.toString().split('.').last},
      );

      return Thumbnail.fromPlatformData(thumbnailData);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting thumbnail: $e');
      }
      rethrow;
    }
  }

  /// Fetches the album thumbnail for the given album ID.
  Future<Thumbnail> getAlbumThumbnail(
    String albumId, {
    MediaType type = MediaType.image,
  }) async {
    final dynamic thumbnailData = await _channel.invokeMethod(
      'getAlbumThumbnail',
      {'albumId': albumId, 'mediaType': type.toString().split('.').last},
    );
    return Thumbnail.fromPlatformData(thumbnailData);
  }

  /// Checks if the app has required permissions
  Future<bool> hasPermission() async {
    return await _channel.invokeMethod('hasPermission') ?? false;
  }

  /// Requests required permissions
  Future<bool> requestPermission() async {
    return await _channel.invokeMethod('requestPermission') ?? false;
  }
}
