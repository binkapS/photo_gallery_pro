# Migration Guide

## 0.0.x → 1.0.0

`photo_gallery_pro` 1.0 stabilizes the API. The changes below are the
complete breaking set; everything else is additive.

### `requestPermission()` returns `PermissionStatus`, not `bool`

```dart
// 0.0.x
final bool granted = await gallery.requestPermission();

// 1.0
final PermissionStatus status = await gallery.requestPermission();
if (!status.canReadMedia) { /* granted or limited? */ }
```

Also, the returned status now reflects the *actual* outcome of the
system dialog — on Android, `requestPermission()` used to return `true`
immediately, before the user answered.

### `Media.path` is deprecated → `uri` + `filePath`

`path` conflated three different things across platforms (Android content
path, iOS empty string, Linux filesystem path). Use:

- `uri` — the platform-native lookup key (Android content URI, iOS
  local identifier, Linux id). Pass this to thumbnail/thumbnail APIs'
  media id arguments.
- `filePath` — a local filesystem path when one exists (`null` for
  cloud-only media and scoped-storage content URIs).

```dart
// 0.0.x
final bytes = File(media.path).readAsBytesSync(); // breaks on iCloud/scoped storage

// 1.0
final bytes = await gallery.getOriginalBytes(media.id);
```

`path` remains as a deprecated alias (`filePath ?? uri`) for one minor
before removal.

### `getMediaInAlbum` defaults to `MediaType.mixed`

```dart
// 0.0.x — videos silently excluded
final media = await gallery.getMediaInAlbum(album.id);

// 1.0 — images and videos together
final media = await gallery.getMediaInAlbum(album.id);
```

Mixed albums (e.g. iOS Camera Roll) are now classified as
`MediaType.mixed` and enumerated in a single call. Pass
`type: MediaType.image` / `MediaType.video` to filter.

### Thumbnails: one canonical shape everywhere

Thumbnails now always carry `{data, width, height, format}` (Android
previously returned bare bytes). `Thumbnail.fromPlatformData` accepts
the new shape plus legacy payloads. New: `size`/`format` parameters and
`getThumbnailBatch` for grids (see README).

### New exception hierarchy

Failures used to surface as generic `PlatformException`s (or `print`
lines). They now surface as typed `PhotoGalleryException`s
(`PermissionDeniedException`, `NotFoundException`, …) — update any
`on PlatformException` handlers that depended on error codes.
