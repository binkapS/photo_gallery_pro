# Changelog

All notable changes to `photo_gallery_pro` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.1.0

Polish release addressing the verification findings in `VERIFICATION.md`
§3 (all items marked Fixed below).

### Added

- `Media.dateCreated` (distinct from `dateAdded`; `created` now prefers it).
- `Album.isSmart` (iOS smart albums, e.g. Camera Roll).
- `PhotoGalleryPro.getMediaById()` facade helper.
- `CloudNotDownloadedException` for `ICLOUD_NOT_DOWNLOADED`;
  `ALBUM_ERROR` maps to `NotFoundException`.
- `SUPPORT.md`.

### Fixed

- `VideoMedia` duration no longer lost on `toJson` round-trip.
- `searchMedia` filters before paginating (matches beyond page 1 found).
- `ThumbnailCache` deduplicates concurrent loads for the same id.
- `Media.fromJson` rejects missing/`mixed` item types instead of silently
  guessing `image`.
- iOS: removed KVC `value(forKey: "fileSize")` for media size (now `0`).
- Android: thumbnail/batch/original-byte results are delivered on the
  main thread, like album/media results.
- Linux: the `~/Pictures` root is exposed as an album so loose files are
  visible; album ids for the root resolve back to the root directory.
- Example: `PhotoViewer` fetches once in `initState`; media grid is
  pull-to-refresh; denied state offers an "Open Settings" hint.

## 1.0.0

Stable release. See [MIGRATION.md](MIGRATION.md) for the 0.0.x → 1.0
migration guide.

### Added

- Full feature set from 0.1.0–0.2.0 (below), stabilized.
- Documentation: README rewrite, migration guide, security policy.
- CI: analyze/format/test + Android, Linux, and iOS builds +
  `pub publish --dry-run` and a 60% lib/ coverage gate.

### Changed

- `Media.path` deprecated in favor of `uri` + `filePath`.
- `requestPermission()` returns `PermissionStatus` (breaking; see
  MIGRATION.md).
- `getMediaInAlbum` defaults to `MediaType.mixed`.
- Android toolchain: Kotlin 1.9.24, AGP 8.4.1, jvmTarget 17.
- iOS podspec: iOS 16.0 minimum, Swift 5.9, privacy manifest ships.

## 0.2.0

### Added

- `MediaType.mixed`: mixed albums enumerate in one call (all platforms).
- Pagination and sorting: `PageRequest` / `MediaSort`, pushed into
  native queries (Android sortOrder LIMIT slicing, iOS fetch options).
- Thumbnail size/format parameters (`ThumbnailSize`, `ThumbnailFormat`)
  and `getThumbnailBatch` for one-call grid loading.
- LRU in-memory `ThumbnailCache` (entry-count + byte-budget eviction).
- `getOriginalBytes` (iCloud-aware errors: `ICLOUD_NOT_DOWNLOADED`).
- `getAlbumById` and `searchMedia` with `MediaQuery` filters
  (name, date range, dimensions, MIME types, minimum duration).

## 0.1.0

### Added

- Proper federated interface: all gallery methods moved into
  `PhotoGalleryProPlatform`; the `PhotoGalleryPro` facade is a thin
  delegate (testable against fakes).
- `MediaType.mixed` with strict `fromString` parsing; `PermissionStatus`
  enum including `limited` and `notDetermined`.
- `Media`: `uri`, `mimeType`, `dateModified`, `filePath`,
  `latitude`/`longitude`; `Album`: `thumbnailMediaId`, `path`,
  `lastModified`; `==`/`hashCode`/`toJson`/`copyWith` on both.
- `Thumbnail` gains `format`; fixed a `fromPlatformData` precedence bug;
  value equality now compares bytes.
- Sealed `PhotoGalleryException` hierarchy mapping native error codes;
  `debugPrint`-guarded logging instead of `print`.

### Fixed

- **Android:** `requestPermission()` now awaits the system dialog
  (`RequestPermissionsResultListener`); `activity` is nullable.
  `getPermissionStatus` covers Android 13+ media grants and Android 14+
  partial access.
- **Android:** album/media queries run off the platform thread;
  album counts aggregated in one pass (no N+1); removed deprecated
  `MediaColumns.DATA` (returns content `uri` instead).
- **iOS:** removed duplicated `getAlbumThumbnail`; all entry points
  gated by authorization; removed `DispatchSemaphore` + synchronous
  image requests; album type classified by content (mixed when both
  images and videos are present); video `duration` from `PHAsset`.
- **Linux:** `getAlbums()` with no type now returns image+video albums
  (previously zero); album id is the directory basename on both
  `getAlbums` and `getMediaInAlbum`; `dateAdded` fixed from
  microseconds to seconds; widened supported extensions; thumbnails
  unified on the `{data,width,height,format}` map with one-pass
  `gdk_pixbuf` at-scale decoding.
- **Example:** manifests/plist declare media permissions; cached
  thumbnail widgets replace `Future`-in-`build`.

## 0.0.9

### Added

- Repo hygiene: CI workflow skeleton, strict lint rules, contributing
  and code-of-conduct docs; pub.dev topics/documentation metadata.
- Android: Kotlin 1.9.24 / AGP 8.4.1 / jvmTarget 17; iOS podspec
  metadata (iOS 16.0, Swift 5.9, privacy manifest shipped).

## 0.0.8

* Fixed video thumbnail generation on Android devices running API < 29 (pre-Android 10)
  * Changed getThumbnail to use file path instead of content URI for ThumbnailUtils.createVideoThumbnail()
  * Added proper file path retrieval from MediaStore for video thumbnails
  * Fixed PlatformException error when generating video thumbnails on older Android versions

## 0.0.7

* Updated docs

## 0.0.6

* Added `path` field to Media model for accessing file system paths
* Fixed Linux implementation to properly return media file paths
* Added proper error handling for inaccessible files
* Updated documentation with path usage examples

## 0.0.5

* Fixed Linux platform support:
  * Fixed method channel error handling
  * Corrected thumbnail generation using GDK-Pixbuf
  * Fixed media type parameter handling
  * Improved error messages for better debugging
  * Added proper null checks for method arguments
  * Fixed directory traversal in album listing
  * Improved memory management for thumbnails
  * Added proper cleanup of GObject resources
