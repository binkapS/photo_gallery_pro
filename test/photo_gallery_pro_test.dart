import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:photo_gallery_pro/photo_gallery_pro.dart';
import 'package:photo_gallery_pro/photo_gallery_pro_method_channel.dart';
import 'package:photo_gallery_pro/photo_gallery_pro_platform_interface.dart';

class FakePhotoGalleryProPlatform extends PhotoGalleryProPlatform {
  String? platformVersionResult = '42';
  PermissionStatus status = PermissionStatus.granted;

  /// Creates a fake platform for tests.
  FakePhotoGalleryProPlatform();

  @override
  Future<String?> getPlatformVersion() async => platformVersionResult;

  @override
  Future<List<Album>> getAlbums({MediaType? type, PageRequest? page}) async =>
      const [];

  @override
  Future<List<Media>> getMediaInAlbum(
    String albumId, {
    MediaType type = MediaType.mixed,
    PageRequest? page,
    MediaSort sort = MediaSort.dateAddedDesc,
  }) async => const [];

  @override
  Future<Thumbnail> getThumbnail(
    String mediaId, {
    ThumbnailSize size = const ThumbnailSize.square(512),
    ThumbnailFormat format = ThumbnailFormat.jpeg,
    MediaType? type,
  }) async => Thumbnail(data: Uint8List(4));

  @override
  Future<Thumbnail> getAlbumThumbnail(
    String albumId, {
    MediaType type = MediaType.mixed,
    ThumbnailSize size = const ThumbnailSize.square(512),
    ThumbnailFormat format = ThumbnailFormat.jpeg,
  }) async => Thumbnail(data: Uint8List(4));

  @override
  Future<Map<String, Thumbnail>> getThumbnailBatch(
    List<String> mediaIds, {
    ThumbnailSize size = const ThumbnailSize.square(256),
    ThumbnailFormat format = ThumbnailFormat.jpeg,
  }) async => <String, Thumbnail>{};

  @override
  Future<Uint8List> getOriginalBytes(String mediaId) async => Uint8List(4);

  @override
  Future<PermissionStatus> getPermissionStatus() async => status;

  @override
  Future<PermissionStatus> requestPermission() async => status;

  @override
  Future<bool> hasPermission() async => status.canReadMedia;
}

void main() {
  final PhotoGalleryProPlatform initialPlatform =
      PhotoGalleryProPlatform.instance;

  test('$MethodChannelPhotoGalleryPro is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelPhotoGalleryPro>());
  });

  test('getPlatformVersion delegates to the platform interface', () async {
    final PhotoGalleryPro photoGalleryProPlugin = PhotoGalleryPro();
    final FakePhotoGalleryProPlatform fakePlatform =
        FakePhotoGalleryProPlatform();
    PhotoGalleryProPlatform.instance = fakePlatform;

    expect(await photoGalleryProPlugin.getPlatformVersion(), '42');
    addTearDown(() {
      PhotoGalleryProPlatform.instance = initialPlatform;
    });
  });

  test('hasPermission reflects the permission status', () async {
    final PhotoGalleryPro gallery = PhotoGalleryPro();
    final FakePhotoGalleryProPlatform fakePlatform =
        FakePhotoGalleryProPlatform();
    PhotoGalleryProPlatform.instance = fakePlatform;

    expect(await gallery.hasPermission(), isTrue);
    fakePlatform.status = PermissionStatus.denied;
    expect(await gallery.hasPermission(), isFalse);
    fakePlatform.status = PermissionStatus.limited;
    expect(await gallery.hasPermission(), isTrue);

    addTearDown(() {
      PhotoGalleryProPlatform.instance = initialPlatform;
    });
  });
}
