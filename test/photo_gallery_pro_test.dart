import 'package:flutter_test/flutter_test.dart';
import 'package:photo_gallery_pro/photo_gallery_pro.dart';
import 'package:photo_gallery_pro/photo_gallery_pro_platform_interface.dart';
import 'package:photo_gallery_pro/photo_gallery_pro_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPhotoGalleryProPlatform
    with MockPlatformInterfaceMixin
    implements PhotoGalleryProPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final PhotoGalleryProPlatform initialPlatform =
      PhotoGalleryProPlatform.instance;

  test('$MethodChannelPhotoGalleryPro is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelPhotoGalleryPro>());
  });

  test('getPlatformVersion', () async {
    PhotoGalleryPro photoGalleryProPlugin = PhotoGalleryPro();
    MockPhotoGalleryProPlatform fakePlatform = MockPhotoGalleryProPlatform();
    PhotoGalleryProPlatform.instance = fakePlatform;

    expect(await photoGalleryProPlugin.getPlatformVersion(), '42');
  });
}
