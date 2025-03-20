# Photo Gallery Pro

A Flutter plugin for accessing and managing photos and videos from the device gallery. Supports both Android and iOS platforms.

## Features

- Browse photo and video albums
- Access media files within albums
- Generate thumbnails for images and videos
- Handle runtime permissions
- Support for Android 13+ and iOS photo library permissions

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  photo_gallery_pro: ^1.0.0
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

### Initialize the Plugin

```dart
import 'package:photo_gallery_pro/photo_gallery_pro.dart';

final photoGallery = PhotoGalleryPro();
```

### Request Permissions

Always check and request permissions before accessing media:

```dart
// Check if permission is granted
bool hasPermission = await photoGallery.hasPermission();

// Request permission if not granted
if (!hasPermission) {
  hasPermission = await photoGallery.requestPermission();
}
```

### Get All Albums

```dart
List<Album> albums = await photoGallery.getAlbums();

// Access album properties
for (var album in albums) {
  print('Album ID: ${album.id}');
  print('Album Name: ${album.name}');
  print('Media Count: ${album.count}');
  print('Media Type: ${album.type}'); // image or video
}
```

### Get Media Files from an Album

```dart
// Get all images from an album
List<Media> images = await photoGallery.getMediaInAlbum(
  albumId,
  type: MediaType.image,
);

// Get all videos from an album
List<Media> videos = await photoGallery.getMediaInAlbum(
  albumId,
  type: MediaType.video,
);

// Access media properties
for (var media in images) {
  print('Media ID: ${media.id}');
  print('File Name: ${media.name}');
  print('Date Added: ${media.dateAdded}');
  print('Width: ${media.width}');
  print('Height: ${media.height}');
  
  // For videos only
  if (media is VideoMedia) {
    print('Duration: ${media.duration}');
  }
}
```

### Generate Thumbnails

```dart
// Get thumbnail for an image
Thumbnail imageThumbnail = await photoGallery.getThumbnail(
  mediaId,
  type: MediaType.image,
);

// Get thumbnail for a video
Thumbnail videoThumbnail = await photoGallery.getThumbnail(
  mediaId,
  type: MediaType.video,
);
```

## Example

```dart
void main() async {
  final photoGallery = PhotoGalleryPro();
  
  // Request permissions
  if (!await photoGallery.hasPermission()) {
    bool granted = await photoGallery.requestPermission();
    if (!granted) {
      print('Permission denied');
      return;
    }
  }
  
  // Get all albums
  List<Album> albums = await photoGallery.getAlbums();
  
  // Get media from first album
  if (albums.isNotEmpty) {
    List<Media> mediaFiles = await photoGallery.getMediaInAlbum(
      albums.first.id,
      type: MediaType.image,
    );
    
    // Get thumbnail for first media item
    if (mediaFiles.isNotEmpty) {
      Thumbnail thumbnail = await photoGallery.getThumbnail(
        mediaFiles.first.id,
        type: MediaType.image,
      );
    }
  }
}
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
