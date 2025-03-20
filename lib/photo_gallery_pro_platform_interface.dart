import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'photo_gallery_pro_method_channel.dart';

abstract class PhotoGalleryProPlatform extends PlatformInterface {
  /// Constructs a PhotoGalleryProPlatform.
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

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
