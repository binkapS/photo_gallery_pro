# photo_gallery_pro example

A demo app for the `photo_gallery_pro` plugin: browse albums, filter
Photos/Videos, view media details, and exercise permission flows
(granted / denied / limited).

## Running

```sh
flutter run          # debug on a connected device/emulator
flutter run --profile  # recommended for scroll-performance checks
```

## Platform setup

### Android

The manifest already declares:

- `READ_EXTERNAL_STORAGE` (Android ≤12)
- `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` (Android 13+)
- `READ_MEDIA_VISUAL_USER_SELECTED` (Android 14+ partial access)

### iOS

`Info.plist` declares `NSPhotoLibraryUsageDescription`. Limited
photo-library access is supported: the demo shows a "Limited photo
access" banner and only the user-selected media is visible.

### Linux

No permissions required. Albums are subdirectories of `~/Pictures`
(top-level files in `~/Pictures` itself are not included). Supported
formats: `jpg jpeg png gif webp tiff tif heic heif bmp` (images),
`mp4 avi mkv mov webm m4v mpeg mpg 3gp` (videos).

## Known limits

- iCloud-only assets expose no `filePath`; the viewer shows
  "(cloud / not locally cached)".
- Thumbnails are cached in-memory (LRU, 500 entries / 20 MB). The
  grid issues at most one platform call per media id.
