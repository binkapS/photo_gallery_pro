# Photo Gallery Pro

<p align="center">
  <a href="https://pub.dev/packages/photo_gallery_pro"><img src="https://img.shields.io/pub/v/photo_gallery_pro.svg" alt="pub.dev"></a>
  <a href="https://github.com/binkapS#sponsor-me"><img src="https://img.shields.io/github/sponsors/binkapS" alt="Sponsoring"></a>
  <a href="https://pub.dev/packages/photo_gallery_pro/score"><img src="https://img.shields.io/pub/likes/photo_gallery_pro" alt="likes"></a>
  <a href="https://pub.dev/packages/photo_gallery_pro/score"><img src="https://img.shields.io/pub/points/photo_gallery_pro" alt="pub points"></a>
</p>

A Flutter plugin for accessing and managing photos and videos from the device gallery. Supports Android, iOS, and Linux platforms.

## Features

- 📱 List all media albums (photos and videos)
- 🖼️ Filter albums by media type (images or videos)
- 📂 Get media items from specific albums
- 🎬 Support for both images and videos
- 👍 Permission handling (on Android and iOS)
- 🔍 Generate thumbnails for:
  - Individual media items
  - Album covers
- ⚡ Optimized performance
- 🎨 Material Design 3 example app

## Platform Support

| Android | iOS | Linux |
|:-------:|:---:|:-----:|
|    ✅    |  ✅  |   ✅   |

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  photo_gallery_pro: ^0.0.4
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

### Linux

Ensure you have the necessary dependencies installed:

```bash
sudo apt-get update
sudo apt-get install libgtk-3-dev pkg-config cmake ninja-build libgdk-pixbuf2.0-dev
```

## Usage

### Basic Setup

```dart
import 'package:photo_gallery_pro/photo_gallery_pro.dart';

// Initialize the plugin
final photoGallery = PhotoGalleryPro();

// Request permissions if needed (not required on Linux)
if (!await photoGallery.hasPermission()) {
  final granted = await photoGallery.requestPermission();
  if (!granted) return;
}
```

### Working with Albums

```dart
// Get all albums
final albums = await photoGallery.getAlbums();

// Or get only image albums
final imageAlbums = await photoGallery.getAlbums(type: MediaType.image);

// Or get only video albums
final videoAlbums = await photoGallery.getAlbums(type: MediaType.video);

// Get album thumbnail
final albumThumbnail = await photoGallery.getAlbumThumbnail(
  albums[0].id,
  type: albums[0].type,
);
```

### Working with Media

```dart
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

## Platform Specific Notes

### Linux

- No explicit permissions are required
- Uses the standard Pictures directory for media access
- Supports common image formats (JPG, PNG) and video formats (MP4, AVI, MKV)
- Thumbnails are generated using GDK-Pixbuf

## Example

Check the [example](example) directory for a complete sample app demonstrating all features.

## Contributing

Feel free to contribute to this project by:

- [Opening issues](https://github.com/binkapS/photo_gallery_pro/issues)
- Submitting pull requests
- Adding documentation
- Reporting bugs

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
