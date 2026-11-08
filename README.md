# Photo Gallery Pro

<p align="center">
  <a href="https://pub.dev/packages/photo_gallery_pro"><img src="https://img.shields.io/pub/v/photo_gallery_pro.svg" alt="pub.dev"></a>
  <a href="https://github.com/binkapS#sponsor-me"><img src="https://img.shields.io/github/sponsors/binkapS" alt="Sponsoring"></a>
  <a href="https://pub.dev/packages/photo_gallery_pro/score"><img src="https://img.shields.io/pub/likes/photo_gallery_pro" alt="likes"></a>
  <a href="https://pub.dev/packages/photo_gallery_pro/score"><img src="https://img.shields.io/pub/points/photo_gallery_pro" alt="points"></a>
</p>

A Flutter plugin for accessing photos and videos from the device media
gallery with a typed, cross-platform Dart API. Supports **Android, iOS,
and Linux**.

```dart
final gallery = PhotoGalleryPro();

final status = await gallery.getPermissionStatus();
if (!status.canReadMedia) {
  await gallery.requestPermission();
}

final albums = await gallery.getAlbums(type: MediaType.mixed);
final media = await gallery.getMediaInAlbum(
  albums.first.id,
  type: MediaType.mixed,               // mixed albums in one call
  page: PageRequest(limit: 100),      // paginate large libraries
  sort: MediaSort.dateAddedDesc,      // newest first
);

final thumb = await gallery.getThumbnail(
  media.first.id,
  size: const ThumbnailSize.square(256),
  format: ThumbnailFormat.jpeg,
);
```

## Features

- 📱 Albums with per-album type classification (`image` / `video` / `mixed`)
- 🖼️ Media in an album with pagination + sorting (pushed to native queries)
- 🎬 Full image + video support, including video duration + MIME type
- 🖼️ Configurable thumbnails (size/format), batched fetches, LRU cache
- 👍 Permission model covering granted / denied / **limited** photo access
- 🔍 Typed errors (`PhotoGalleryException` hierarchy) instead of strings
- ⚡ Off-platform-thread queries; no main-thread blocking (iOS included)
- 🧩 Federated plugin: mock `PhotoGalleryProPlatform` in tests

## Platform Support

| Android | iOS | Linux |
|:-------:|:---:|:-----:|
|    ✅    |  ✅  |   ✅   |

## Installation

```yaml
dependencies:
  photo_gallery_pro: ^1.0.0
```

## Platform Setup

### Android

The plugin's `AndroidManifest.xml` declares:

- `READ_EXTERNAL_STORAGE` (Android ≤12)
- `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` (Android 13+)
- `READ_MEDIA_VISUAL_USER_SELECTED` (Android 14+ partial access)

Your app should also declare the permissions it needs (the demo app does).

### iOS

Your app's `Info.plist` must declare `NSPhotoLibraryUsageDescription`.
Limited photo-library access is supported: when the user grants access to
a subset of photos, `PermissionStatus.limited` reports it and queries see
only the selected media.

### Linux

No permissions required. Albums are subdirectories of `~/Pictures`.
Supported formats: `jpg jpeg png gif webp tiff tif heic heif bmp`
(images), `mp4 avi mkv mov webm m4v mpeg mpg 3gp` (videos).

## API

| Method | Description |
|---|---|
| `getPermissionStatus()` | Current `PermissionStatus` (granted/limited/denied/…) |
| `requestPermission()` | Shows the system prompt; completes *after* it resolves |
| `hasPermission()` | `true` for granted or limited access |
| `getAlbums({type, page})` | All albums; `type` defaults to `mixed` |
| `getMediaInAlbum(id, {type, page, sort})` | Paginated, sorted media |
| `getAlbumById(id)` | Single album lookup, or `null` |
| `getThumbnail(id, {size, format, type})` | One thumbnail |
| `getAlbumThumbnail(id, {type, size, format})` | Representative album thumbnail |
| `getThumbnailBatch(ids, {size, format})` | `Map<String, Thumbnail>` for grids |
| `getOriginalBytes(id)` | Full-resolution bytes (may download from iCloud) |
| `searchMedia(id, query, {...})` | `MediaQuery` filtering (name/date/size/mime/duration) |

### Models

| `Media` field | Notes |
|---|---|
| `id` | Opaque platform id (treat as opaque) |
| `uri` | Platform-native lookup key — **use this** to request bytes |
| `filePath` | Local path, only when the file is actually cached locally (`null` for cloud/scoped-storage) |
| `name` / `filename` | File name |
| `dateAdded` / `created` | Epoch-seconds date the platform reports |
| `dateModified`, `mimeType`, `size`, `width`, `height` | Metadata, `0`/`null` when unknown |
| `latitude` / `longitude` | GPS, when exposed (location permission) |
| `duration` | Videos only (`Duration`, milliseconds) |

| `Album` field | Notes |
|---|---|
| `id` | Opaque (Android bucket / iOS collection / Linux dir name) |
| `name`, `count`, `type` | Display name, item count, classified `MediaType` |
| `thumbnailMediaId` | Newest item in the album |
| `path` | Linux only (album directory) |
| `lastModified` | Newest item's added date |

### Errors

Failures throw typed exceptions (all `PhotoGalleryException` subclasses):

| Exception | Native code | Meaning |
|---|---|---|
| `PermissionDeniedException` | `PERMISSION_ERROR` | No gallery access |
| `NotFoundException` | `NOT_FOUND` | Album/media vanished |
| `UnsupportedMediaTypeException` | `INVALID_TYPE` | Bad type argument |
| `ThumbnailException` | `THUMBNAIL_ERROR` | Thumbnail generation failed |
| `PlatformGalleryException` | other | Platform-specific failures |

## Caching thumbnails

```dart
final cache = ThumbnailCache(maxEntries: 500, maxBytes: 20 << 20);
final thumb = await cache.getOrLoad(
  media.id,
  () => gallery.getThumbnail(media.id, size: const ThumbnailSize.square(256)),
);
```

## Migrating from 0.0.x

See [MIGRATION.md](MIGRATION.md). In short: `requestPermission()` now
returns `PermissionStatus`, `Media.path` is deprecated in favor of
`uri`/`filePath`, `getMediaInAlbum` defaults to `MediaType.mixed`, and
thumbnails return a canonical map on every platform.

## Example

See [example/](example/) for a full demo (filter chips, pull-to-refresh,
limited-access banner, media detail viewer).

## Contributing & Security

- [CONTRIBUTING.md](CONTRIBUTING.md) — development workflow and gates
- [SECURITY.md](SECURITY.md) — how to report vulnerabilities privately
- The method-channel contract lives in `plan.md` Appendix B.

## License

MIT — see [LICENSE](LICENSE).
