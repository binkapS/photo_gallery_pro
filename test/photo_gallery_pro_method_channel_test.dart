import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_gallery_pro/photo_gallery_pro.dart';
import 'package:photo_gallery_pro/photo_gallery_pro_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelPhotoGalleryPro platform = MethodChannelPhotoGalleryPro();
  const MethodChannel channel = MethodChannel('photo_gallery_pro');

  final List<MethodCall> calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          calls.add(methodCall);
          switch (methodCall.method) {
            case 'getPlatformVersion':
              return '42';
            case 'getAlbums':
              return <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': '1',
                  'name': 'A',
                  'count': 1,
                  'type': 'image',
                },
              ];
            case 'getMediaInAlbum':
              return <Map<String, dynamic>>[
                <String, dynamic>{'id': '10', 'name': 'p.jpg', 'type': 'image'},
              ];
            case 'getPermissionStatus':
              return 'limited';
            case 'requestPermission':
              return 'granted';
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });

  test('getAlbums sends mediaType by enum name', () async {
    final albums = await platform.getAlbums();
    expect(calls.single.method, 'getAlbums');
    final args = calls.single.arguments as Map<dynamic, dynamic>;
    expect(args.containsKey('mediaType'), isFalse);
    expect(albums.single.id, '1');
  });

  test(
    'getMediaInAlbum sends albumId/mediaType/sort and parses media',
    () async {
      final media = await platform.getMediaInAlbum('album-1');
      final args = calls.single.arguments as Map<dynamic, dynamic>;
      expect(args['albumId'], 'album-1');
      expect(args['mediaType'], 'mixed');
      expect(args['sort'], 'dateAddedDesc');
      expect(media.single.id, '10');
    },
  );

  test('getPermissionStatus parses the status string', () async {
    expect(await platform.getPermissionStatus().then((s) => s.name), 'limited');
  });

  test('platform exceptions surface as typed gallery exceptions', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          throw PlatformException(code: 'PERMISSION_ERROR', message: 'nope');
        });

    expect(
      () => platform.getAlbums(),
      throwsA(isA<PermissionDeniedException>()),
    );
  });
}
