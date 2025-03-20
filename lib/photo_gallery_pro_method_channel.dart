import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'photo_gallery_pro_platform_interface.dart';

/// An implementation of [PhotoGalleryProPlatform] that uses method channels.
class MethodChannelPhotoGalleryPro extends PhotoGalleryProPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('photo_gallery_pro');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
