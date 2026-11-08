import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:photo_gallery_pro/photo_gallery_pro.dart';
import 'package:photo_gallery_pro/photo_gallery_pro_method_channel.dart';
import 'package:photo_gallery_pro/photo_gallery_pro_platform_interface.dart';

class FakePhotoGalleryProPlatform extends PhotoGalleryProPlatform {
  String? platformVersionResult = '42';
  PermissionStatus status = PermissionStatus.granted;
  List<Album> albums = const [];
  List<Media> media = const [];

  /// Creates a fake platform for tests.
  FakePhotoGalleryProPlatform();

  @override
  Future<String?> getPlatformVersion() async => platformVersionResult;

  @override
  Future<List<Album>> getAlbums({MediaType? type, PageRequest? page}) async =>
      albums;

  @override
  Future<List<Media>> getMediaInAlbum(
    String albumId, {
    MediaType type = MediaType.mixed,
    PageRequest? page,
    MediaSort sort = MediaSort.dateAddedDesc,
  }) async => media;

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

  test('searchMedia filters before paginating', () async {
    final PhotoGalleryPro gallery = PhotoGalleryPro();
    final FakePhotoGalleryProPlatform fakePlatform =
        FakePhotoGalleryProPlatform();
    PhotoGalleryProPlatform.instance = fakePlatform;
    fakePlatform.media = <Media>[
      ImageMedia(
        id: '1',
        name: 'cat.jpg',
        uri: '1',
        dateAdded: DateTime(2025),
        size: 1,
        width: 10,
        height: 10,
      ),
      ImageMedia(
        id: '2',
        name: 'dog.jpg',
        uri: '2',
        dateAdded: DateTime(2025),
        size: 1,
        width: 10,
        height: 10,
      ),
      ImageMedia(
        id: '3',
        name: 'cat2.jpg',
        uri: '3',
        dateAdded: DateTime(2025),
        size: 1,
        width: 10,
        height: 10,
      ),
    ];

    // Page of 1 must see the last match, not just the first page item.
    final List<Media> results = await gallery.searchMedia(
      'album',
      const MediaQuery(nameContains: 'cat'),
      page: const PageRequest(offset: 1, limit: 1),
    );
    expect(results.map((Media m) => m.id), <String>['3']);

    addTearDown(() {
      PhotoGalleryProPlatform.instance = initialPlatform;
    });
  });

  test('getMediaById finds media across albums', () async {
    final PhotoGalleryPro gallery = PhotoGalleryPro();
    final FakePhotoGalleryProPlatform fakePlatform =
        FakePhotoGalleryProPlatform();
    PhotoGalleryProPlatform.instance = fakePlatform;
    fakePlatform.albums = const <Album>[
      Album(id: 'a1', name: 'A', count: 1, type: MediaType.image),
    ];
    fakePlatform.media = <Media>[
      ImageMedia(
        id: '9',
        name: 'x.jpg',
        uri: '9',
        dateAdded: DateTime(2025),
        size: 1,
        width: 1,
        height: 1,
      ),
    ];

    expect((await gallery.getMediaById('9'))?.id, '9');
    expect(await gallery.getMediaById('missing'), isNull);

    addTearDown(() {
      PhotoGalleryProPlatform.instance = initialPlatform;
    });
  });
}
