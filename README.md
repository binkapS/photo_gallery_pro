# Photo Gallery Pro

A Flutter plugin for accessing and managing photos and videos from the device gallery. Supports both Android and iOS platforms.

## Features

* List all media albums (photos and videos)
* Get media items from specific albums
* Generate thumbnails for media items
* Get album thumbnails (cover images)
* Permission handling for gallery access
* Support for both images and videos

## Getting Started

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  photo_gallery_pro: ^0.0.2
```

## Platform Setup

### Android

Add the following permissions to your Android Manifest (`android/app/src/main/AndroidManifest.xml`):

```xml
<!-- For Android 12 and below -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />

<!-- For Android 13 and above -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
```

### iOS

Add the following keys to your iOS Info.plist (`ios/Runner/Info.plist`):

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>This app requires access to the photo library to display your photos and videos.</string>
```

## Usage

```dart
import 'package:photo_gallery_pro/photo_gallery_pro.dart';

// Initialize the plugin
final photoGallery = PhotoGalleryPro();

// Request permissions if needed
if (!await photoGallery.hasPermission()) {
  final granted = await photoGallery.requestPermission();
  if (!granted) return;
}

// Get all albums
final albums = await photoGallery.getAlbums();

// Get album thumbnail
final albumThumbnail = await photoGallery.getAlbumThumbnail(
  albums[0].id,
  type: albums[0].type,
);

// Get media in an album
final mediaList = await photoGallery.getMediaInAlbum(
  albums[0].id,
  type: albums[0].type,
);

// Get thumbnail for a specific media item
final thumbnail = await photoGallery.getThumbnail(
  mediaList[0].id,
  type: mediaList[0].type,
);
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
