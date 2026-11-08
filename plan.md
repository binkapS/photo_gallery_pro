# `photo_gallery_pro` — Comprehensive Improvement Plan

> **Document type:** Roadmap / Technical Improvement Plan (historical — see status below)
> **Project:** `photo_gallery_pro` (Flutter federated plugin: Dart ↔ Android/Kotlin, iOS/Swift, Linux/GTK+ C)
> **Current version in `pubspec.yaml`:** `1.1.0`
> **Status:** ✅ **Implemented.** All phases (0–8) shipped in `1.0.0`; verification findings were fixed in `1.1.0`. See [`VERIFICATION.md`](VERIFICATION.md) for the audit and the per-item fix list. This document is kept as the design record; the "Current-State Inventory" (§2) and findings (§3–§5) describe the pre-plan `0.0.8` state, not the current code.
> **Date:** 2026-11-08 (plan) · 2026-11-08 (verified + fixed in `1.1.0`)
> **Scope:** API correctness, platform parity, performance, security/privacy, testing, CI, docs & pub.dev readiness, example app, and new features

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Current-State Inventory](#2-current-state-inventory)
3. [Critical Findings (P0)](#3-critical-findings-p0)
4. [High-Priority Findings (P1)](#4-high-priority-findings-p1)
5. [Medium / Low Findings (P2/P3)](#5-medium--low-findings-p2p3)
6. [Roadmap Overview](#6-roadmap-overview)
7. [Phase 0 — Foundations & Repo Hygiene (1–2 days)](#7-phase-0--foundations--repo-hygiene-12-days)
8. [Phase 1 — Dart API & Platform Contract Fix (1 week)](#8-phase-1--dart-api--platform-contract-fix-1-week)
9. [Phase 2 — Android Correctness, Permissions & Performance (1–2 weeks)](#9-phase-2--android-correctness-permissions--performance-12-weeks)
10. [Phase 3 — iOS Correctness, Permissions & Performance (1–2 weeks)](#10-phase-3--ios-correctness-permissions--performance-12-weeks)
11. [Phase 4 — Linux Correctness & Parity (1 week)](#11-phase-4--linux-correctness--parity-1-week)
12. [Phase 5 — Feature Additions (2–4 weeks, incremental)](#12-phase-5--feature-additions-24-weeks-incremental)
13. [Phase 6 — Testing & CI (1 week, then ongoing)](#13-phase-6--testing--ci-1-week-then-ongoing)
14. [Phase 7 — Example App Rebuild (3–5 days)](#14-phase-7--example-app-rebuild-35-days)
15. [Phase 8 — Documentation, Migration & pub.dev Release (2–3 days)](#15-phase-8--documentation-migration--pubdev-release-23-days)
16. [Risk Register](#16-risk-register)
17. [Effort & Milestone Matrix](#17-effort--milestone-matrix)
18. [Acceptance Criteria & Definition of Done](#18-acceptance-criteria--definition-of-done)
19. [Appendix A — Target API Sketch](#appendix-a--target-api-sketch)
20. [Appendix B — Method-Channel Contract](#appendix-b--method-channel-contract)
21. [Appendix C — Per-File Change Checklist](#appendix-c--per-file-change-checklist)

---

## Implementation status (added 2026-11-08)

| Phase | Commit | Version | Status |
|-------|--------|---------|--------|
| 0 — Foundations | `947c0d8` | 0.0.9 | ✅ Done |
| 1 — Dart contract | `bb0cfd9` | 0.1.0 | ✅ Done |
| 2 — Android | `6fac664` | — | ✅ Done |
| 3 — iOS | `9606b13` | — | ✅ Done |
| 4 — Linux | `f7549d8` | — | ✅ Done |
| 5 — Features | `8b3cc4a` | 0.2.0 | ✅ Done (P2/P3 deferred by design) |
| 6 — Testing & CI | `33ffd90` | — | ✅ Done |
| 7 — Example | `0308631` | — | ✅ Done |
| 8 — Docs & 1.0 | `32c6d9d` | 1.0.0 | ✅ Done |
| Verification fixes | *(this change)* | 1.1.0 | ✅ Done — see `VERIFICATION.md` §3 (Fixed) |

Deferred to a future release (see `VERIFICATION.md` §3): `observeChanges` streams, media mutation, macOS/Windows/web, native push-down pagination (Android `LIMIT` / iOS `fetchLimit`), Linux native unit tests, iOS native test target.

---

## 1. Executive Summary

`photo_gallery_pro` is a Flutter plugin (~`0.0.8`, MIT, 3 platforms) that exposes:

- `PhotoGalleryPro` Dart facade (`lib/photo_gallery_pro.dart`)
- Albums (`getAlbums`, `getAlbumThumbnail`)
- Media in an album (`getMediaInAlbum`, `getThumbnail`)
- Permissions (`hasPermission`, `requestPermission`)
- Native implementations for **Android (Kotlin, `PhotoGalleryProPlugin.kt`, 505 lines)**, **iOS (Swift, `PhotoGalleryProPlugin.swift`, 384 lines)**, and **Linux (GTK+/C, `photo_gallery_pro_plugin.cc`, 516 lines)**

The plugin already has real users-facing value, but today it is **not pub.dev-complete and not platform-parity-complete**:

- The federated plugin contract is **broken**: `PhotoGalleryProPlatform` only implements `getPlatformVersion`; all real methods bypass it and call a raw `MethodChannel` directly from the facade class. Tests and third-party platform implementations cannot substitute it.
- **Documentation does not match the code**: `README.md` installation pins `^0.0.4` while `pubspec.yaml` is `0.0.8`; model docs use `media.filename`, `media.created`, `media.mimeType`, `thumb.bytes` which do not exist (`name`, `dateAdded`, `Thumbnail.data`).
- **Permissions never actually resolve on Android**: `requestPermission()` returns `true` immediately without waiting for the system dialog, and there is no `onRequestPermissionsResult` / `ActivityResult` callback, so denial/partial grants are silently ignored.
- **iOS blocks the main thread synchronously** (`DispatchSemaphore` + `requestImageDataAndOrientation(isSynchronous: true)`) inside `getMediaInAlbum`, risking UI hangs/ANR-like stalls on large libraries.
- **Thumbnail sizes, formats, and return types are inconsistent across platforms**: Android returns raw `ByteArray`, iOS returns `FlutterStandardTypedData`, Linux `getThumbnail` returns `{data,width,height}` map but `getAlbumThumbnail` returns a bare `uint8_list`; the Dart layer has to heuristically guess.
- **No pagination, sorting, or filtering beyond media-type** — large galleries allocate unbounded lists and repeat `N+1` ContentResolver queries on Android.
- **Almost no test coverage**: two trivial template tests in Dart, one Android unit test that asserts a `getPlatformVersion` path Android doesn't implement, and a Linux test for the same dead path. No CI workflow.
- **No `mixed` media support**, despite `README` claiming `MediaType.mixed` and Android `getAlbums` documenting it as possible.

**Goal of this plan:** bring the plugin to a **stable `1.0` pub.dev release** with:

1. Correct, typed, documented Dart API with a proper federated interface.
2. Permission-correct Android + iOS flows (including Android 13+/14 partial-access and iOS Limited).
3. Unified thumbnails/caching and pagination/performance.
4. Full platform parity and a reproducible CI gate (`dart format`, `flutter analyze`, `flutter test`, Android/Kotlin build, iOS `pod lib lint`, Linux build).

---

## 2. Current-State Inventory

### 2.1 What exists today

| Area | Files | Status |
|------|-------|--------|
| Dart facade | `lib/photo_gallery_pro.dart` (98 lines) | Works, but bypasses platform interface; 5 methods + `getPlatformVersion` |
| Platform interface | `lib/photo_gallery_pro_platform_interface.dart` (29 lines) | Template-only: only `getPlatformVersion` |
| Method-channel impl | `lib/photo_gallery_pro_method_channel.dart` (19 lines) | Template-only: only `getPlatformVersion` |
| Models | `lib/src/album.dart`, `media.dart`, `media_type.dart`, `thumbnail.dart` | Basic, untested, inconsistent `fromJson` / `toString` / `==` |
| Android | `android/src/main/kotlin/.../PhotoGalleryProPlugin.kt`, `android/build.gradle`, `AndroidManifest.xml` | Most complete of the three, but permission-result bug, deprecated `DATA` column, template tests |
| iOS | `ios/Classes/PhotoGalleryProPlugin.swift`, `ios/photo_gallery_pro.podspec`, `ios/Resources/PrivacyInfo.xcprivacy` | Duplicated album-thumbnail code, main-thread blocking, stale podspec |
| Linux | `linux/photo_gallery_pro_plugin.cc` + `CMakeLists.txt` + headers | Functional but narrow extensions, album-id/path mismatch, type inconsistencies |
| Example | `example/lib/main.dart` (335 lines), dual manifests | M3 demo works, but builds `Future` in `build()`; no caching; permission manifest in example is **missing** |
| Tests | `test/*` (2 files, ~55 lines), Android + Linux template tests | Only `getPlatformVersion` |
| Docs | `README.md` (197 lines), `CHANGELOG.md` (85 lines) | Out of sync with code and version |
| CI/CD | — | **None**: no `.github/workflows`, no `melos.yaml`, no `Makefile` |

### 2.2 Platform-method inventory (what the channel actually supports)

| Method | Android | iOS | Linux | Dart facade | Notes |
|--------|:-------:|:---:|:-----:|:-----------:|-------|
| `getPlatformVersion` | ❌ (not implemented) | ❌ | ❌ (only C++ helper) | ✅ (via platform interface) | Template leftover; Android/Linux template tests assert it — they'll fail |
| `getAlbums` | ✅ | ✅ | ✅ | ✅ (raw channel) | `mixed` unsupportable everywhere |
| `getMediaInAlbum` | ✅ | ✅ | ✅ (but different id semantics) | ✅ (defaults `type=image`) | No pagination/sort |
| `getThumbnail` | ✅ (async executor) | ✅ | ✅ | ✅ | Hardcoded 320 (Android/iOS) vs 512 (Linux) |
| `getAlbumThumbnail` | ✅ (async) | ✅ (duplicated impls) | ✅ | ✅ | iOS checks auth; others don't |
| `hasPermission` / `requestPermission` | ✅ (buggy request) | ✅ | ✅ (`true` stub) | ✅ | Android returns before dialog resolves |

### 2.3 Dependency / toolchain snapshot

| Item | Current | Risk |
|------|---------|------|
| Dart SDK | `^3.7.2` | Fine |
| Flutter constraint | `>=3.3.0` | Very permissive; hard to guarantee API compat |
| `flutter_lints` | `^5.0.0` | Fine; no custom rules |
| Kotlin | `1.8.0` (in `android/build.gradle`) | Behind current Flutter/Kotlin baseline |
| AGP | `7.3.1` | Behind `compileSdk = 35` requirement; build warnings expected |
| `compileSdk` / `minSdk` | `35` / `21` | Modern; `ThumbnailUtils.createVideoThumbnail` path still needed <Q |
| iOS podspec | `s.platform = :ios, '12.0'`, `swift_version '5.0'`, `version '0.0.1'` | Stale: Apple requires ≥17 for new apps; podspec version ≠ pubspec |
| `PrivacyInfo.xcprivacy` | Empty arrays, `NSPrivacyTracking=false` | `resource_bundles` commented out in podspec → manifest never ships |
| CMake | `3.10` | Matches Flutter requirement; keep |

---

## 3. Critical Findings (P0)

These are correctness / crash / hang bugs. Fix before any feature work.

### 3.1 C1 — Federated platform interface is a dead shell
**Evidence:** `lib/photo_gallery_pro.dart` holds its own `static const MethodChannel _channel` and calls it directly for every method; `lib/photo_gallery_pro_platform_interface.dart` + `_method_channel.dart` only declare `getPlatformVersion`. `getAlbums/getMediaInAlbum/getThumbnail/...` are *not* in the interface, so:
- unit-testing the facade requires mocking the wire channel, not the interface;
- third parties cannot ship their own platform implementations (the point of federated plugins);
- `plugin_platform_interface` is depended on but effectively unused.

**Fix:** Phase 1 (§8): move all five methods into `PhotoGalleryProPlatform` / `MethodChannelPhotoGalleryPro`, simplify `PhotoGalleryPro` to a thin delegate. Keep `getPlatformVersion` only as a debug helper or remove it in `1.0`.

### 3.2 C2 — Android `requestPermission()` never awaits the dialog
**Evidence:** `PhotoGalleryProPlugin.kt:439-457`
```kotlin
ActivityCompat.requestPermissions(activity, arrayOf(...), PERMISSION_REQUEST_CODE)
result.success(true)   // unconditional, immediate
```
There is no `onRequestPermissionsResult` / `onActivityResult` and `activity` is a `lateinit var` set in `onAttachedToActivity` — if a configuration change or background engine detaches, the next call crashes with `UninitializedPropertyAccessException`.

**Fix:** §9. Use `ActivityResultLauncher` (or register a permission-callback), guard `activity` with `::activity.isInitialized`, and return the *actual* grant status. Also add **Android 14 partial access** (`READ_MEDIA_VISUAL_USER_SELECTED`) — currently `hasPermission()` requires *both* `READ_MEDIA_IMAGES+READ_MEDIA_VIDEO` on 13+, so partial grant is reported as denied even when the user allowed photos only.

### 3.3 C3 — Android + iOS block the platform thread for media lists
- **Android:** `getAlbums`/`getMediaInAlbum` run `contentResolver.query` on the Flutter platform thread; `getAlbums` loops every bucket and then issues one extra `query` per bucket (`getAlbumCount` uses `cursor.count` after loading all rows in memory).
- **iOS:** `getMediaInAlbum` calls `getAssetLocalURL`, which does a synchronous `requestImageDataAndOrientation` with a **30-second semaphore wait** *per asset* on the caller thread; large albums = guaranteed hang.

**Fix:** §9/§10 — move queries to a background executor/queue, add `limit/offset/sort` pushed down to the native side, and remove synchronous image-data requests (use `PHImageManager` async with a single completion, or `PHAssetResourceManager.copy` only when the caller explicitly asks for bytes).

### 3.4 C4 — iOS duplicated `getAlbumThumbnail` + unauthorized access paths
`PhotoGalleryProPlugin.swift` defines **two** `getAlbumThumbnail` functions (lines 229-259 and 261-343). The first is dead code that re-implements the same logic with divergent options (`isNetworkAccessAllowed=false` vs `true`, `resizeMode .fast` vs `.exact`). `getAlbums` and `getMediaInAlbum` do **not** check authorization at all — violating App Store privacy expectations and potentially returning incomplete data when only Limited access was granted.

**Fix:** §10 — keep one implementation, gate every entry point through `checkAuthorization`, surface `PHPhotoLibraryAuthorizationStatus` (authorized / limited / denied / notDetermined) distinctly in Dart.

### 3.5 C5 — Android uses deprecated/removed columns (`DATA`)
`getMediaInAlbum` projects `MediaStore.MediaColumns.DATA` (removed for scoped storage on Android 10+). This breaks `path` on modern devices and fails App Store-/Play-review scans for broad storage access. iOS likewise computes `path` via a KVC hack (`resource.value(forKey: "fileSize")`) that is not a public API and can break across OS updates.

**Fix:** §9 — return a stable **content `uri`** (Android) / `localIdentifier` + optional `filePath` only when actually cached (iOS). Never rely on `DATA` or KVC. Update `Media.path` semantics and document them.

### 3.6 C6 — Album-id semantics differ per platform (breaking)
- Android: `id = MediaStore.BUCKET_ID`.
- iOS: `id = PHAssetCollection.localIdentifier`.
- Linux: `id = directory name` in `getAlbums`, but `getMediaInAlbum` treats `albumId` as a **full filesystem path** (`g_file_new_for_path(album_id)`), while `get_first_media_in_album` treats it as a **basename** under `~/Pictures` — so the album you get from `getAlbums` cannot be passed to `getMediaInAlbum` without rebuilding the path yourself.

**Fix:** §11 — define one contract: `id` is opaque; document per-platform meaning; make Linux accept the id returned by `getAlbums`.

### 3.7 C7 — Linux `getAlbums(null type)` path is broken
`get_albums` forwards the raw `media_type` (possibly `nullptr`) into `process_directory` → `get_media_count(dir, media_type)`, which does `g_strcmp0(media_type, "image")` / `g_strcmp0(media_type, "video")` with `nullptr`. `g_strcmp0` tolerates `nullptr`, so the call silently counts **nothing** when no filter is set — meaning `getAlbums()` (no args) returns zero albums. The current `example/lib/main.dart` calls `getAlbums()` with no type, so Linux silently shows a blank grid.

**Fix:** §11 — make no-filter mean “both” (aggregate images+videos), make `process_directory` deduplicate by directory name, fix dimension/date handling (see §5).

### 3.8 C8 — Example app cannot request permission on Android/iOS
`example/android/app/src/main/AndroidManifest.xml` declares **no** media permissions; `example/ios/Runner/Info.plist` declares **no** `NSPhotoLibraryUsageDescription`. The example therefore cannot legally pass the permission step the plugin requires, despite `main.dart` handling permission-denied UI.

**Fix:** §14 — add the missing manifest/plist entries plus `NSAppTransportSecurity`/foreground-use strings as needed, and the iOS `PhotoLibrary` capability note.

---

## 4. High-Priority Findings (P1)

### 4.1 H1 — Model ↔ README contract drift
| README says | Code actually has | File |
|---|---|---|
| `media.filename` | `media.name` | `media.dart` |
| `media.created` | `media.dateAdded` | `media.dart` |
| `media.mimeType` | *(missing)* | `media.dart` |
| `MediaType.mixed` | *(missing)* | `media_type.dart` |
| `thumb.bytes`, `thumb.width/height` | `Thumbnail.data`, `width`, `height` | `thumbnail.dart` |
| `photo_gallery_pro: ^0.0.4` | `pubspec.yaml` = `0.0.8`, podspec = `0.0.1` | repo-wide |

**Fix:** Either add the missing fields (recommended — see §12) or rewrite README with the real API. This plan recommends the former under a `0.1.0` minor bump, then `1.0` stability.

### 4.2 H2 — Android `getMediaInAlbum` is image-only at the API level
Dart defaults `type = MediaType.image` and requires the caller to pass the album's type; a **mixed album** (typical for iOS “Camera Roll”, Android shared buckets) cannot be enumerated in one call. Album `type` is derived from the *first* asset on iOS and from the query URI on Android/Linux, so it is unreliable.

**Fix:** Introduce `MediaType.mixed`, make native `getMediaInAlbum` query both tables/collections when `mixed` is requested, and sort client-side by `dateAdded DESC` (pushing sort into the native query where possible).

### 4.3 H3 — Thumbnail API is unparameterized and inconsistent
- Sizes are hardcoded (320 on Android/iOS, 512 in Dart fallback, 200 for Linux album thumbs).
- Return shapes differ (see §2.2).
- `Thumbnail.fromPlatformData` has a subtle operator-precedence bug (line 23):
  ```dart
  final data = map['data'] ?? map['bytes'] as Uint8List?;
  ```
  `??` does not group with `as`, so if `map['data']` is non-null the `as` is never applied; if `map['data']` is null the cast runs on `map['bytes']` bytes — behavior depends on types SQLite returns. And `data == other.data` on `Uint8List` is identity equality, so `Thumbnail ==` is effectively `identical`.

**Fix:** §8: typed `ThumbnailRequest {width,height,format}` params, single canonical return `{data,width,height,format}`, `listEquals`-based equality, `hashCode` via `Object.hash`.

### 4.4 H4 — No error hierarchy
Every failure is a generic `PlatformException` or `FormatException`; Dart `getThumbnail` prints to stdout and rethrows. Consumers cannot distinguish “no permission”, “not found”, “unsupported type”, “iCloud not downloaded”, “file vanished”.

**Fix:** §8: sealed `PhotoGalleryException` hierarchy + documented error codes (see Appendix B).

### 4.5 H5 — Inefficient / uncached thumbnail loading in the example
`_buildAlbumGrid`/`_buildMediaGrid` build a `FutureBuilder` whose `future:` is created **inside `build()`** — every rebuild re-issues the platform call, so scrolling a grid of 200+ thumbs hammers the method channel and GC churns `Uint8List`s. No `ImageCache`, `MemoryImage` dedup, or cancellation on dispose.

**Fix:** §14: introduce a small Dart `ThumbnailCache` (LRU, size-capped) + widgets (`AlbumThumb`, `MediaThumb`) backed by `Stream`/`ValueNotifier`, or document that consumers must do this. Never allocate a new Future in `build` of the shipped example.

### 4.6 H6 — `print` instead of `debugPrint` / logging
`lib/photo_gallery_pro.dart:72` uses `print`; `example/lib/main.dart` uses several `print` for flow tracing. In release, `print` is never throttled and pollutes logs.

**Fix:** §8/§14: `debugPrint` with `kDebugMode` guard, or adopt `logging`/`talker`. Respect `kReleaseMode` silencing by default.

### 4.7 H7 — `Album.fromJson` / `Media.fromJson` never validate `mixed` or bad payloads
`Album.fromJson` maps *anything* that isn’t `'image'` to `MediaType.video`, including `'mixed'`, `null`, or typos. `Media.fromJson` does the same. `VideoMedia.duration` is read as `int?` milliseconds but iOS never sends it (so all iOS videos report `Duration.zero`).

**Fix:** §8: strict parsing with `ArgumentError`/`FormatException` on unknown values; add `duration` to iOS (from `PHAsset.duration`).

---

## 5. Medium / Low Findings (P2/P3)

| # | Area | Issue | Where |
|---|------|-------|-------|
| M1 | Android | `getAlbums` calls `getAlbumCount` per bucket → `N+1` queries; `cursor.count` materializes every row just to count | `PhotoGalleryProPlugin.kt:139,472-480` |
| M2 | Android | Thread pool (`thumbnailExecutor`) is never shut down; if many thumbs race, 2 threads queue | `:497-499, 502-504` |
| M3 | Android | `capitalize()` deprecated in Kotlin; `toLowerCase()` without locale | `:187,264` |
| M4 | Android | Tests assert `getPlatformVersion` Android doesn't implement → failing tests | `PhotoGalleryProPluginTest.kt:19-28` |
| M5 | Android | AGP `7.3.1` + Kotlin `1.8.0` mismatch with `compileSdk 35` | `android/build.gradle` |
| M6 | iOS | `getAlbums` filters via `fetchOptions.predicate` but then classifies album *type* by first asset only | `PhotoGalleryProPlugin.swift:94-108` |
| M7 | iOS | `getThumbnail` ignores `mediaType` entirely; always requests a still image (works for video poster frames, but not documented) | `:193-227` |
| M8 | iOS | `PHAssetResource` accessed via `value(forKey: "fileSize")` (KVC) to compute `size` | `:139` |
| M9 | iOS | Two duplicated thumbnail request blocks; `isAssetCached` helper is dead code | `:229-259,345-351` |
| M10 | iOS | `import PhotosUI` unused | `:4` |
| M11 | Linux | Extension allowlist too narrow: `jpg/jpeg/png` + `mp4/avi/mkv` only. Misses `webp/heic/heif/gif/tiff/raw/dng`, `mov/webm/mpeg/m4v` | `photo_gallery_pro_plugin.cc:48-58` |
| M12 | Linux | `process_directory` only looks at top-level dirs of `~/Pictures`; root files in `~/Pictures` itself are ignored; no recursion, no XDG `G_USER_DIRECTORY_VIDEOS` | `:70-109,432` |
| M13 | Linux | Date unit mismatch: `time::modified` is in µs since epoch; Dart multiplies by `1000` expecting seconds → year ~56000 | `:370-384` |
| M14 | Linux | `get_media_in_album` never sets `width/height` for videos and never sets `duration` | `:392-410` |
| M15 | Linux | `get_thumbnail` treats `mediaId` as a file path directly; `get_album_thumbnail` saves PNG while Android/iOS save JPEG | `:249-311,191-246` |
| M16 | Linux | `generate_thumbnail` re-decodes full images with `gdk_pixbuf_new_from_file` (no `gdk_pixbuf_new_from_file_at_scale`, no cache, no thread pool) | `:156-189` |
| M17 | Dart | `Media` is `abstract` with a factory that returns subclasses, but the `Media` constructor itself is public and the subclasses don't override `==/hashCode` | `media.dart:10-68` |
| M18 | Dart | `Thumbnail` equality uses `==` on `Uint8List` (identity) | `thumbnail.dart:39-45` |
| M19 | Dart | `Media`/`Album` have no `toJson`/`fromJson` round-trip, no `copyWith`, no `Equatable`/`json_serializable` path | `album.dart, media.dart` |
| M20 | Dart | `type.toString().split('.').last` stringly-typed on every call; native side re-`lowercase()`s | `photo_gallery_pro.dart:24,40,59,84` |
| M21 | Dart | `getAlbums({MediaType? type})` accepts `null` (means “all”) but `getMediaInAlbum` defaults to `image` — asymmetric; callers must thread album type manually | `:21-47` |
| M22 | Dart | No pagination args anywhere; all lists are fully materialized | `photo_gallery_pro.dart` |
| M23 | Dart | `Uri` vs `path` ambiguity: Android `DATA` path, iOS empty string when iCloud-only, Linux full path — one field, three meanings | `media.dart, PhotoGalleryProPlugin.swift:149-153` |
| M24 | iOS | `PrivacyInfo.xcprivacy` exists but podspec never ships it | `photo_gallery_pro.podspec:28` |
| M25 | iOS | Podspec hardcodes `version '0.0.1'`, homepage `example.com`, author `Your Company` | `photo_gallery_pro.podspec:6-15` |
| M26 | Android | `AndroidManifest.xml` in the plugin declares permissions, but the *example* manifest omits them (see C8) | `example/android/.../AndroidManifest.xml` |
| M27 | Linux | `CMakeLists.txt` `apply_standard_settings` + test block is template-copied; it never links `gdk-pixbuf` explicitly (relies on transitive `PkgConfig::GTK`) | `linux/CMakeLists.txt` |
| M28 | Linux | No `gnome-desktop` / `tracker` integration; “album” = directory, which misleads users expecting system gallery apps | design |
| M29 | README | License badge absent; sponsor badge points to sponsor repo, not the package | `README.md` |
| M30 | Repo | No `.github/workflows`, no `LICENSE` mismatch (MIT file ok, but podspec says `:file => '../LICENSE'` with stale metadata), no `melos` for example+plugin | repo root |
| M31 | Repo | `.metadata` and `pubspec.lock` committed (lockfile is ok for apps, unnecessary for plugins) | repo root |
| M32 | Dart | `analysis_options.yaml` is stock; no public-member docs enforced, no `prefer_single_quotes` tuning | `analysis_options.yaml` |
| M33 | Example | `withOpacity` → `withAlpha` already fixed but still manual alpha math; no `Theme.of(context).colorScheme.*` polish; no empty-state / error-state per album | `example/lib/main.dart` |
| M34 | Example | `FutureBuilder` without `initialData`/`cached` futures; no `AutomaticKeepAliveClientMixin` in grid | `example/lib/main.dart` |
| M35 | Platform | No `macOS` / `Windows` / `web` declarations — plugin is mobile+Linux only but `pubspec.yaml` doesn't say so; `flutter create` on unsupported platforms gives cryptic errors | `pubspec.yaml` |
| M36 | Linux | C++ uses raw `FL_METHOD_RESPONSE(...)` macro dance and `nullptr`/`NULL` mixed; no `g_autoptr` for some early returns → leak on errors | `photo_gallery_pro_plugin.cc` |
| M37 | Android | `FourTuple` helper class leaks abstraction; could be sealed data class / `Triple` + payload | `PhotoGalleryProPlugin.kt:409` |
| M38 | iOS | `getAlbums` uses `.album` + `.smartAlbum` but skips `.userLibrary` explicitly; Camera Roll classification depends on subtype order | `:76-88` |
| M39 | Docs | `CHANGELOG.md` versions don't match git tags (no tags visible) | `CHANGELOG.md` |
| M40 | Tests | `MockPlatformInterfaceMixin` is deprecated in newer `plugin_platform_interface`; should use `MockPlatformInterface` or a fake via `PlatformInterface.verify` bypass | `test/photo_gallery_pro_test.dart` |

---

## 6. Roadmap Overview

```
Phase −1  Decide  →  Phase 0 hygiene  →  Phase 1 Dart contract  →  Phase 2 Android
                                                                →  Phase 3 iOS
                                                                →  Phase 4 Linux
        ↓                                                            ↓
Phase 5 features (mixed, pagination, cache, errors)  →  Phase 6 tests/CI
        ↓                                                    ↓
Phase 7 example rebuild  →  Phase 8 docs & 1.0 release
```

**Ordering principle:** contract before implementations (changing IDs/types after ship is a breaking change). Android/iOS/Linux can be parallelized once the channel contract (Appendix B) is frozen.

**Priority legend:**

- **P0** — blocks correctness / release (must fix before `1.0`)
- **P1** — required for a good `0.1.0` / strong `1.0`
- **P2** — nice to have, ship in `1.1`
- **P3** — exploratory / backlog

**Effort legend:** S ≤ 2 days, M = 3–5 days, L = 1–2 weeks.

---

## 7. Phase 0 — Foundations & Repo Hygiene (1–2 days) [P0]

**Goal:** make the repo buildable-by-anyone and the next phases un-blocked.

### 7.1 Tasks

| # | Task | Files |
|---|------|-------|
| 0.1 | Pin CI-reproducible Flutter version (`.fvmrc` or `flutter-version` in CI) and lock `pubspec.yaml` plugin constraints (`flutter: '>=3.22.0'` if dropping older) | `pubspec.yaml`, `.fvmrc` |
| 0.2 | Set `version: 0.0.9` for the hygiene bump; align `podspec` version & `README` install line to `${version}` placeholder or scripted bump | `pubspec.yaml`, `ios/.../*.podspec`, `README.md` |
| 0.3 | Remove `pubspec.lock` from git (plugin package), add to `.gitignore` properly; keep `example/pubspec.lock` | `.gitignore` |
| 0.4 | Enable strict lints: `public_member_api_docs`, `prefer_final_fields`, `unnecessary_import`, `use_key_in_widget_constructors`, plus documented `lints` for example | `analysis_options.yaml` |
| 0.5 | Add `.github/workflows/ci.yml` skeleton: `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test`, Android/Kotlin build, iOS `pod lib lint`, Linux `cmake`+build | `.github/workflows/ci.yml` |
| 0.6 | Add `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md` (or at least issue/PR templates) | repo root |
| 0.7 | Fix podspec metadata: homepage, `s.version`, `s.platform = :ios, '16.0'` (match Flutter's minimum), `swift_version '5.9'`, enable `s.resource_bundles` for privacy manifest, add `s.frameworks` review | `ios/photo_gallery_pro.podspec` |
| 0.8 | Upgrade Android toolchain: Kotlin `1.9.x`+ / AGP `8.2.x`, `compileSdk 34/35` consistency, `minSdk 21` → `23` if dropping pre-Marshmallow (decide explicitly) | `android/build.gradle` |
| 0.9 | Add `topics`, `documentation`, `example` and `funding` fields to `pubspec.yaml` so `pub.dev` scoring passes | `pubspec.yaml` |

**Acceptance:** `flutter analyze` and `flutter test` pass from a clean checkout; CI is green on `main`.

---

## 8. Phase 1 — Dart API & Platform Contract Fix (1 week) [P0/P1]

### 8.1 Move all methods into the federated interface
**Current:** `PhotoGalleryPro` owns the channel.
**Target:** `PhotoGalleryPro` delegates to `PhotoGalleryProPlatform.instance`.

```dart
// lib/photo_gallery_pro_platform_interface.dart
abstract class PhotoGalleryProPlatform extends PlatformInterface {
  ...
  Future<List<Album>> getAlbums({MediaType? type, PageRequest? page});
  Future<List<Media>> getMediaInAlbum(String albumId, {MediaType type = MediaType.mixed, PageRequest? page});
  Future<Thumbnail> getThumbnail(String mediaId, {ThumbnailSize size = const ThumbnailSize(512,512), ThumbnailFormat format = ThumbnailFormat.jpeg});
  Future<Thumbnail> getAlbumThumbnail(String albumId, {MediaType type = MediaType.mixed, ThumbnailSize size = const ThumbnailSize(512,512)});
  Future<bool> hasPermission();
  Future<bool> requestPermission();
  Future<PermissionStatus> getPermissionStatus(); // new, see 8.4
}
```

- `lib/photo_gallery_pro_method_channel.dart`: implement each via `invokeMethod` with typed responses (`invokeListMethod<Map>`, validation).
- `lib/photo_gallery_pro.dart`: drop the private `MethodChannel`, delegate, keep only DTO re-exports.

### 8.2 Fix models
- **`MediaType`**: add `mixed` (`enum MediaType { image, video, mixed }`) and a `MediaTypeX.fromString` extension; reject unknown strings loudly.
- **`Album`**: add `id`, `name`, `count`, `type`, **plus** `thumbnailMediaId` (optional), `isSmart` / `path` (Linux), `lastModified`. Implement `==/hashCode`, `toJson`, `copyWith`, `toString` with id.
- **`Media`**: add `uri` (platform URI/identifier), `mimeType`, `dateModified`, `dateCreated` (distinct from `dateAdded`), `duration` for videos, `size`, `latitude/longitude` (optional, gated by location permission). Deprecate `path` in favor of `uri` + `filePath` (nullable, only when local). Provide `toJson`/`fromJson` that round-trips.
- **`Thumbnail`**: `data` (Uint8List), `width`, `height`, `format` (`png`/`jpeg`), `hashCode` via `Object.hashAll`. Fix `fromPlatformData` precedence bug (`map['data'] ?? map['bytes']`).
- **`PhotoGalleryException`**: sealed hierarchy (`PermissionDeniedException`, `NotFoundException`, `UnsupportedMediaTypeException`, `ThumbnailException`, `PlatformGalleryException`) with `code`, `message`, `details`.

### 8.3 Typed channel arguments
Replace `type.toString().split('.').last` everywhere with `type.name` and a single `MediaTypeArgument` serializer.

### 8.4 Permission model
```dart
enum PermissionStatus { granted, denied, restricted, limited, permanentlyDenied }
```
- `getPermissionStatus()` maps Android/iOS status to this; `hasPermission()` becomes `status == granted || status == limited`.
- `requestPermission()` returns `Future<PermissionStatus>` (breaking change – ship in `0.1.0`, note in `CHANGELOG.md` + `MIGRATION.md`).

### 8.5 Documentation in code
Every public symbol gets a `///` doc example that compiles under `dartdoc`. This is a `pub.dev` scoring gate.

**Acceptance:** `flutter analyze` passes with no infos on `lib/`; Dart unit tests (Phase 6) mock `PhotoGalleryProPlatform` and verify the facade never touches a `MethodChannel`.

---

## 9. Phase 2 — Android Correctness, Permissions & Performance (1–2 weeks) [P0/P1]

### 9.1 Permission flow rewrite (C2)
- Register a `RequestPermissionLauncher` on the binding (`registerForActivityResult`) or implement `onRequestPermissionsResult`. `requestPermission()` must complete **after** the system dialog.
- Guard `activity`: `private var activity: Activity? = null`.
- `hasPermission` semantics:
  - **Android 13+** (`READ_MEDIA_IMAGES`/`READ_MEDIA_VIDEO`): `granted` if either is granted; `limited` if `READ_MEDIA_VISUAL_USER_SELECTED` granted.
  - **≤12**: `READ_EXTERNAL_STORAGE`.
- Example manifest gets the three permissions + `READ_MEDIA_VISUAL_USER_SELECTED` documented as optional.

### 9.2 Query off the platform thread (C3/M1)
- Wrap `contentResolver.query` in a dedicated `ExecutorService`/coroutine scope; `result.success` must be posted on the main thread via a `Handler(Looper.getMainLooper())` (Flutter `Result` is main-thread-requiring) or use the existing `thumbnailExecutor` pattern uniformly.
- `getAlbumCount`: replace `cursor.count` with a single `COUNT(*)` projection (`"count(*) as c"`), or compute counts in one grouped query (`GROUP BY BUCKET_ID`).
- Sort: push `DATE_ADDED DESC` / `DISPLAY_NAME ASC` into `sortOrder`; add `limit/offset` via `LIMIT` (Android 11+ `LIMIT` param of `query` via `Bundle`).

### 9.3 Replace `DATA` column (C5)
- Project instead: `_ID`, `DISPLAY_NAME`, `MIME_TYPE`, `DATE_ADDED`, `DATE_MODIFIED`, `SIZE`, `WIDTH`, `HEIGHT`, `DURATION`, `BUCKET_ID`, `RELATIVE_PATH`.
- Build `uri = ContentUris.withAppendedId(MediaStore.Images/Video.Media.EXTERNAL_CONTENT_URI, id)` and return it as `uri`.
- `filePath`: only when `MediaStore.MediaColumns.DATA` is readable (pre-Q) — otherwise `null`.

### 9.4 Thumbnails: configurable size
- `ThumbnailUtils.createVideoThumbnail` / `MediaStore.Images.Thumbnails.getThumbnail` accept a `Size`; expose `size` params from Dart; default `512×512`, API for callers to request `256×256` for grids (40% smaller payloads).
- Use `ThumbnailUtils.createVideoThumbnail` only as fallback under Q; Q+ uses `loadThumbnail`.

### 9.5 Kotlin hygiene
- Kotlin `1.9.x`, AGP `8.2.x`, `kotlinOptions.jvmTarget = "17"`.
- Replace `capitalize()`/`toLowerCase()` with `replaceFirstChar { it.uppercase() }` / `lowercase(Locale.ROOT)`.
- Extract `FourTuple` → tuple of (`uri`, `projection`, `selection`, `sortOrder`).
- Shut down `thumbnailExecutor` in `onDetachedFromEngine`.

**Acceptance:** No `runCheckedThread`-style blocking on platform thread for `getAlbums`/`getMediaInAlbum` with 10k-item fixture (see Phase 6 perf test); permission denial is surfaced; `flutter test` + `./gradlew testDebugUnitTest` green.

---

## 10. Phase 3 — iOS Correctness, Permissions & Performance (1–2 weeks) [P0/P1]

### 10.1 Deduplicate + gate everything (C4)
- Delete the dead first `getAlbumThumbnail` (`:229-259`). Keep the one that sorts and filters by type (`:261-343`).
- Every `handle` case (`getAlbums`, `getMediaInAlbum`, `getThumbnail`) must run the same authorization check; `getAlbumThumbnail`'s current `checkAuthorization` path becomes the shared gate.
- Return a distinct `PermissionStatus` (authorized/limited/denied) instead of `true/false`; map Limited photo-library access results to `limited` with a `limitedAssetCount`.
- Add `NSPhotoLibraryUsageDescription` note: Limited access is a user choice; document it.

### 10.2 Remove synchronous blocking (C3/M8)
- **No** `isSynchronous = true` + `DispatchSemaphore` inside enumeration. Replace with the async `requestImageDataAndOrientation` pattern or, better, `PHAssetResourceManager.copy` only if `needsFilePath` is explicitly requested, otherwise omit `path`.
- Compute `size` from `PHAssetResourceManager` file size *without* KVC (use ` PHAssetResourceManager.default().resource(for:)` + `value(forKey:)` → `resource.value(forKey: "fileSize")` is public enough but prefer `PHAssetResource.fileSize` when available, or omit `size` and let Dart compute from downloaded bytes).
- Return `duration` from `asset.duration` for videos; return `mimeType` from `PHAssetResource?.mimeType` / `UTType`.

### 10.3 Album semantics
- Include smart albums with their `localizedTitle`, mark `isSmart`. Skip `.any` subtype in favor of explicit enumeration so `Camera Roll`, `Screenshots`, `Videos`, `Slomo`, etc. appear predictably.
- Classify album `type` by *content* (`fetchOptions.predicate` results) rather than first asset: count images and videos separately; `mixed` when both >0.

### 10.4 Pod / privacy
- Ship `PrivacyInfo.xcprivacy` (uncomment `s.resource_bundles`).
- `s.platform = :ios, '16.0'`, `s.swift_version = '5.9'`, metadata fill, `pod lib lint` clean.

**Acceptance:** Xcode `Analyze` clean; UI never blocks while enumerating 5k-asset fixture; Limited-access picker (`PHPhotoLibrary.requestAuthorization(.readWrite)`) flows correctly.

---

## 11. Phase 4 — Linux Correctness & Parity (1 week) [P0/P1]

### 11.1 Album contract (C6/C7)
- `getAlbums` with `media_type == nullptr` must return **all** albums (images+videos deduped by directory). Audit `process_directory`/`get_media_count` to aggregate.
- Standardize `id` = **relative directory name** (basename) on both `getAlbums` and `getMediaInAlbum`; `get_first_media_in_album` already expects this — make `get_media_in_album` do the same (`g_file_new_for_path(g_build_filename(pictures_dir, album_id, NULL))`) instead of treating `albumId` as a full path.
- Decide: root of `~/Pictures` *is* an album named e.g. `Pictures` (so loose files aren't invisible). Optionally add `XDG Pictures/Videos` aggregation via `g_get_user_special_dir(G_USER_DIRECTORY_PICTURES/VIDEOS)`.

### 11.2 Media enumeration
- Fix `dateAdded`: `time::modified` is µs; convert to **seconds** once (`mtime / G_TIME_SPAN_MILLISECOND`) – Dart multiplies by 1000, so native should send seconds.
- Always populate `width/height/duration`: for videos use `gdk-pixbuf` poster or `gst` metadata if available; otherwise send `0` explicitly (so `fromJson` never sees missing keys).
- Widen extensions: images `jpg jpeg png gif webp tiff tif heic heif bmp`; videos `mp4 avi mkv mov webm m4v mpeg mpg 3gp`.

### 11.3 Thumbnails
- Unify return shape: **always** `{data, width, height}` map (Dart understands both; pick the map and align `getAlbumThumbnail` to match `getThumbnail`).
- Use `gdk_pixbuf_new_from_file_at_scale` (one-pass, less memory) and a small LRU file cache (`~/.cache/photo_gallery_pro/thumbs/`).
- Frame the 200→512 default-size drift: accept `width/height` from Dart (Phase 1), cap at `4096`.

### 11.4 Memory/error discipline
- Use `g_autoptr`/`g_autofree` on every early return; check `g_file_enumerate_children` / `g_file_enumerator_next_file` for `nullptr` and `GError`.
- `CMakeLists.txt`: link `PkgConfig::GDK_PIXBUF` explicitly; keep `3.10` floor per Flutter docs.

**Acceptance:** Linux example shows albums on `getAlbums()` no-arg call; album→media round-trip works without reconstructing paths; no GLib criticals under `G_DEBUG=fatal-criticals`.

---

## 12. Phase 5 — Feature Additions (2–4 weeks, incremental) [P1/P2]

Ship each as a separate minor bump with docs + example. **All are additive on `0.1.0`, breaking pre-`1.0` is avoided.**

### 12.1 [P1] `MediaType.mixed` + mixed albums
`getAlbums(type: mixed)` returns every album; `getMediaInAlbum` with `mixed` queries both URIs/collections and interleaves by `dateAdded DESC`.

### 12.2 [P1] Pagination & sorting
```dart
class PageRequest { int offset = 0; int? limit; }
enum MediaSort { dateAddedDesc, dateAddedAsc, nameAsc, sizeDesc }
Future<List<Media>> getMediaInAlbum(id, {MediaType type, PageRequest? page, MediaSort sort})
```
Native: push `LIMIT`/`OFFSET`/sortOrder down where supported (Android `query(..., sortOrder with LIMIT)`, iOS `fetchLimit`/`fetchOffset`).

### 12.3 [P1] `Thumbnail` size/format params + `ImageFormat` enum
Caller controls size; bytes never exceed ~`size.w × size.h × 2` JPEG. Add `getThumbnailBatch(ids, size)` returning a `Map<String, Thumbnail>` to amortize channel hops for grids.

### 12.4 [P1] `ThumbnailCache` (Dart, optional)
```dart
class ThumbnailCache {
  ThumbnailCache({int maxEntries = 500, int maxBytes = 20 << 20});
  Future<Thumbnail> getOrLoad(String id, Future<Thumbnail> Function() loader);
}
```
L2: optional disk cache via `path_provider` (behind a separate `photo_gallery_pro_cache` package if you want to keep this plugin dependency-free).

### 12.5 [P2] `getMediaById`, `getAlbumById`, `contentUri` resolution
Fast path for detail screens; no album scan required.

### 12.6 [P2] `originalFile` / byte loading
`Future<Uint8List> getOriginalBytes(String mediaId)` — scoped to request (iCloud warning; requires user-initiated download; document the data budget).

### 12.7 [P2] `observeChanges()` / `albumChanges()`
`Stream<List<Album>>` via native content observers (`ContentObserver` Android, `PHPhotoLibraryChangeObserver` iOS, `GFileMonitor` Linux) so galleries stay in sync without polling. Emit `MediaChange {added, removed, updated}`.

### 12.8 [P2] Location / EXIF / format metadata
`latitude`, `longitude`, `exifOrientation`, `orientation`, `isFavorite`, `isHidden`, `isTrashed` (iOS `favorite`/`hidden`, Android flags). Gate pixel-location exposure on permission.

### 12.9 [P2] Search & date filtering
`searchMedia(query: {nameContains, dateFrom, dateTo, minWidth/minHeight, mimeTypes, minDuration})` — implement as filtered `getMediaInAlbum` internally; native push-down when cheap.

### 12.10 [P3] Media mutation (save/delete/move)
Consider whether this plugin should stay **read-only**; if write is wanted, put it behind `PhotoGalleryPro.saveImageToGallery(filePath)` with scoped-storage-safe impl (MediaStore on Android 10+, `PHPhotoLibrary` on iOS). Document Play policy implications at length before shipping.

### 12.11 [P3] Platform expansion
- **macOS** (`photo_gallery_pro_macos`): reuse iOS code path (`Photos` framework, `macOS 11+`).
- **Windows**: file-system roots (`Pictures/Videos/Saved Pictures`).
- **Web**: `html.Dio`-free `showOpenFilePicker`/`<input type=file>`; thumbnail via `CanvasImageSource`. These are large; track as `1.x` conversation, not `1.0`.

---

## 13. Phase 6 — Testing & CI (1 week, then ongoing) [P0/P1]

### 13.1 Dart unit tests (`test/`)
| File | What to cover |
|------|---------------|
| `album_test.dart` | `fromJson` strictness (`mixed` rejected-by-default, round-trip, `==`) |
| `media_test.dart` | image vs video `fromJson`, ms/s timestamp, `duration`, missing-field defaults throw |
| `thumbnail_test.dart` | `fromPlatformData` for both map & `Uint8List` shapes; equality; empty-data `FormatException` |
| `photo_gallery_pro_test.dart` | facade delegates to mock `PhotoGalleryProPlatform`; platform exceptions surface verbatim |
| `photo_gallery_pro_method_channel_test.dart` | each method sends the expected payload (incl. `type.name`) and parses the response; error `PlatformException` passthrough |
| `media_type_test.dart` | `fromString` rejects unknown types |

Replace deprecated `MockPlatformInterfaceMixin` with `MockPlatformInterface` or a hand-written fake.

### 13.2 Native tests
- **Android:** fix the existing unit test (it asserts `getPlatformVersion` Android doesn't implement). Add a Robolectric test for `requestPermission` callback routing and a `ThumbnailSize` test. Run `./gradlew testDebugUnitTest`.
- **iOS:** add `RunnerTests` or an SPM test target invoking the plugin via `FlutterMethodChannel` mock; assert authorization gating (denied ⇒ `FlutterError(PERMISSION_ERROR)`).
- **Linux:** reuse the GTest harness; test `process_directory` no-filter aggregation and `get_media_in_album` id→path mapping with a tmpdir fixture.

### 13.3 Golden / perf tests (P2)
- Record jank during a 500-thumb scroll; assert thumbnail LRU hit-rate >80% and zero `Future` rebuilds.
- Memory profile: 100-image album must keep RSS growth <50 MB.

### 13.4 CI workflow (`.github/workflows/ci.yml`)
```yaml
jobs:
  analyze: { runs-on: ubuntu-latest, steps: [flutter pub get, dart format --set-exit-if-changed, flutter analyze, flutter test] }
  android: { runs-on: ubuntu-latest, steps: [./gradlew assembleDebug, ./gradlew testDebugUnitTest] }
  linux: { runs-on: ubuntu-latest, steps: [apt install libgtk-3-dev ..., cmake --build build/linux/x64/debug] }
  ios: { runs-on: macos-latest, steps: [pod lib lint, flutter build ios --no-codesign] }
```
Plus a `pub publish --dry-run` step so signature/metadata errors surface before tagging.

**Acceptance:** `main` is green on all four jobs; coverage gate ≥60% on `lib/` (enforce `lcov` threshold, ratchet upward).

---

## 14. Phase 7 — Example App Rebuild (3–5 days) [P1]

### 14.1 Fix the build
- Add Android permissions + iOS usage description (C8).
- `analysis_options.yaml` for the example: same lints as plugin.

### 14.2 Replace `Future`-in-`build` with cached widgets
```dart
class AlbumThumb extends StatefulWidget { ... } // fetches once in initState, caches in ImageCache
class MediaThumb extends StatelessWidget { final String id; ... } // uses ThumbnailCache
```
- Grid builders keep `AutomaticKeepAliveClientMixin`; use `cacheWidth/cacheHeight` from `ThumbnailSize`.
- Add a **filter chip bar** (`All / Photos / Videos`) exercising `getAlbums(type:)` and `getMediaInAlbum(type: mixed)`.
- Add **pull-to-refresh**, **empty state**, **denied-state with “Open Settings”** deep link, and **limited-access banner** (iOS).
- Add a `PhotoViewer` stub showing `Media.uri`/`filePath`, `size`, `duration`, `mimeType` — proving the new fields are wired.

### 14.3 Docs inside the example
`example/README.md`: run instructions per platform, required permissions, supported formats, known limits (Linux top-level dirs, iCloud download).

**Acceptance:** Profile-mode example scrolls a 500-item album at 60 fps without re-issuing channel calls (verify via DevTools channel log); example passes `flutter build apk/appbundle/ios/linux` cleanly.

---

## 15. Phase 8 — Documentation, Migration & pub.dev Release (2–3 days) [P0 for 1.0]

### 15.1 README rewrite (single source of truth)
- Version-synced install snippet; platform setup per OS (with the *new* permission names); full API table; model field tables; error-code table; migration notes from `0.0.x`.
- Feature matrix (“rich”) + screenshot/GIF, troubleshooting (scoped-storage `DATA` removal, iCloud `path` empty, Limited access).
- Badges: pub.dev version/score/likes/points already present; add CI status badge once Phase 6 lands.

### 15.2 `CHANGELOG.md` discipline
- Keep-`Keep a Changelog` format: `Added / Changed / Fixed / Removed`.
- Every entry references an issue/PR; breaking changes get a `BREAKING:` prefix and a `MIGRATION.md` entry.

### 15.3 Release checklist (`1.0`)
- [ ] `pubspec.yaml` version `1.0.0`, `topics`, `documentation` populated, `flutter pub publish --dry-run` clean, `pub.dev` score ≥130/160
- [ ] `flutter pub publish` from a clean clone works; example has `publish_to: none`
- [ ] iOS `pod lib lint` clean; `PrivacyInfo.xcprivacy` ships; podspec version == pubspec version
- [ ] Android: `android:exported` audit, scoped-storage Play policy note, R8/proguard note
- [ ] License (`MIT`) + `SECURITY.md` (reporting) + `SUPPORT.md` (supported versions)
- [ ] Tag `v1.0.0`, archive release notes, publish to pub.dev

### 15.4 Consider a `docs/` folder alongside README
Move the deep dive (channel contract, permission flow, platform parity, perf notes) out of README so README stays skimmable; link from README.

---

## 16. Risk Register

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Breaking API (`requestPermission` return type, `Media.path` semantics) upsets existing users | `0.0.8` consumers break on upgrade | Ship as `0.1.0` with a `MIGRATION.md`; bump to `1.0` only after deprecation cycle; keep `path` as a deprecated alias for one minor |
| iOS async refactor changes completion ordering | Thumbnail races | Cover with integration test; keep sync API as deprecated shim for one release |
| Android 14 / 15 partial-access nuance | Users with photo-only grants see empty videos | Test on Android 14/15 emulators with both grants; document in README |
| Linux has few users; over-investing delays `1.0` | Slows mobile release | Treat Linux as parity-tracked (Phase 4) not feature-leading; freeze features at Phase 5 S1–S4 |
| Pub.dev points penalties for missing homepage/issues/documentation | Ranking drop | Phase 0.9 + Phase 8 checklists |
| Play Store / App Store review rejects broad-storage or KVC | Rejection / removal | Remove `DATA`/KVC (Phase 2/3); ship privacy manifest; document scoped-storage compliance |

---

## 17. Effort & Milestone Matrix

| Milestone | Date target | Scope | Version |
|-----------|-------------|-------|---------|
| **M0 — Hygiene** | Week 1 | Phase 0 | `0.0.9` |
| **M1 — Contract** | Week 2 | Phase 1 | `0.1.0-dev` |
| **M2 — Mobile parity** | Week 4 | Phase 2 + 3 (parallel) | `0.1.0` |
| **M3 — Linux parity** | Week 5 | Phase 4 | `0.1.0` |
| **M4 — Features** | Week 8 | Phase 5 (S1–S4) | `0.2.0` |
| **M5 — Hardened** | Week 9 | Phase 6 + 7 | `0.2.0` + docs |
| **M6 — 1.0** | Week 10 | Phase 8 audit + deprecations removed | `1.0.0` |

Elapsed estimate assumes one maintainer; with two contributors (one mobile, one Dart) M2 halves.

---

## 18. Acceptance Criteria & Definition of Done

A task is **done** when:
1. Code is formatted (`dart format`), analyzed (`flutter analyze` no warnings), and covered by a unit/integration test that fails when the bug is reintroduced.
2. **README / CHANGELOG** entry exists with named symbols.
3. Platform parity is asserted: the same Dart call succeeds on Android, iOS, and Linux (or a documented, tested reason it can't).
4. Example exercises the feature end-to-end on at least one platform (screenshot/GIF in the PR).
5. `pub publish --dry-run` still passes.

**Release gates (`1.0`):** all P0 + P1 items merged; CI green (analyze/test/android/linux/ios); `pub.dev` publish dry-run clean; podspec `pod lib lint`; example builds for all declared platforms.

---

## Appendix A — Target API Sketch

```dart
import 'package:photo_gallery_pro/photo_gallery_pro.dart';

final gallery = PhotoGalleryPro();

// Permissions
final status = await gallery.getPermissionStatus(); // granted | limited | denied
if (status == PermissionStatus.notDetermined) {
  await gallery.requestPermission();
}

// Albums (paginated, mixed-aware)
final albums = await gallery.getAlbums(
  type: MediaType.mixed,
  page: PageRequest(offset: 0, limit: 50),
);

// Media in an album (mixed by default; sorted newest-first)
final media = await gallery.getMediaInAlbum(
  albums.first.id,
  type: MediaType.mixed,
  sort: MediaSort.dateAddedDesc,
  page: PageRequest(offset: 0, limit: 100),
);

// Thumbnails (explicit size; batched for grids)
final thumb = await gallery.getThumbnail(
  media.first.id,
  size: const ThumbnailSize.square(256),
  format: ThumbnailFormat.jpeg,
);

final thumbs = await gallery.getThumbnailBatch(
  media.take(50).map((m) => m.id),
  size: const ThumbnailSize.square(256),
);

// Batch / cache
final cache = ThumbnailCache(maxEntries: 500);
final t = await cache.getOrLoad(media[0].id, () => gallery.getThumbnail(media[0].id));

// Original bytes (user-initiated; may download from iCloud)
final bytes = await gallery.getOriginalBytes(media[0].id);

// Change feed (P2)
await gallery.albumChanges().listen((change) { /* reload */ });
```

---

## Appendix B — Method-Channel Contract

Channel: `photo_gallery_pro` (`StandardMethodCodec`). All args are `String`/`int`/`bool`/`null`; binary payloads are `Uint8List`.

### Methods

| Method | Args | Returns | Errors |
|--------|------|---------|--------|
| `getAlbums` | `{mediaType?: string, offset?: int, limit?: int}` | `List<{id,name,count,type,thumbnailMediaId?,isSmart?}>` | `INVALID_TYPE`, `PERMISSION_ERROR`, `ALBUMS_ERROR` |
| `getMediaInAlbum` | `{albumId: string, mediaType: string, offset?: int, limit?: int, sort?: string}` | `List<{id,uri,name,mimeType,type,dateAdded,dateModified,size,width,height,duration?,path?}>` | `INVALID_ARGUMENTS`, `PERMISSION_ERROR`, `FETCH_ERROR` |
| `getThumbnail` | `{mediaId: string, width?: int, height?: int, format?: string}` | `{data: Uint8List, width: int, height: int, format: string}` (always a map; Android joins the current byte path behind a map) | `INVALID_ARGUMENTS`, `NOT_FOUND`, `THUMBNAIL_ERROR` |
| `getAlbumThumbnail` | `{albumId: string, mediaType: string, width?: int, height?: int}` | same as `getThumbnail` | `INVALID_ARGUMENTS`, `ALBUM_ERROR`, `THUMBNAIL_ERROR` |
| `getThumbnailBatch` | `{mediaIds: List<string>, width?: int, height?: int}` | `Map<string, {data,width,height,format}>` | per-id `NOT_FOUND` entries do not fail the whole batch |
| `getOriginalBytes` | `{mediaId: string}` | `Uint8List` | `NOT_FOUND`, `ICLOUD_NOT_DOWNLOADED` |
| `hasPermission` | `{}` | `bool` (derived from `getPermissionStatus().canReadMedia`) | — |
| `requestPermission` | `{}` | `string` status (`granted/limited/denied/...`) — Dart `Future<PermissionStatus>` | — |
| `getPermissionStatus` | `{}` | `string: granted\|limited\|denied\|restricted\|notDetermined` | — |
| `getPlatformVersion` | `{}` | `string` (display/debug only) | — |

### Field semantics (all platforms)

- `id` is **opaque**: Android `MediaStore` `_ID` stringified / iOS `localIdentifier` / Linux basename.
- `uri` is the platform-native lookup key (`content://media/.../<id>` Android; the `id` itself iOS; the `id` on Linux). `path` (nullable) is only a convenience for locally-cached files.
- `dateAdded` is **epoch seconds** everywhere (Dart multiplies by 1000).
- `size` is **bytes**; omit (or `0`) rather than guessing when the platform can't provide it.
- Unknown `mediaType` strings are rejected with `INVALID_TYPE`.

---

## Appendix C — Per-File Change Checklist

| File | Phase | Change |
|------|-------|--------|
| `lib/photo_gallery_pro.dart` | 1 | Delegate to platform interface; remove raw channel |
| `lib/photo_gallery_pro_platform_interface.dart` | 1 | Add all 5+ methods + `PermissionStatus`, `PageRequest`, exception types |
| `lib/photo_gallery_pro_method_channel.dart` | 1 | Implement all methods; typed returns |
| `lib/src/media_type.dart` | 1 | Add `mixed`, `fromString`, extension helpers |
| `lib/src/album.dart` | 1 | `==/hashCode/toJson/copyWith`, `thumbnailMediaId` |
| `lib/src/media.dart` | 1 | `uri/mimeType/dateModified/duration/location`, strict `fromJson` |
| `lib/src/thumbnail.dart` | 1 | `format`, fix `fromPlatformData`, `listEquals` |
| `lib/src/*` (new) | 1/5 | `permission_status.dart`, `page_request.dart`, `thumbnail_cache.dart`, `exceptions.dart` |
| `android/.../PhotoGalleryProPlugin.kt` | 2 | Permission launcher, background queries, `uri`, configurable thumbs, executor shutdown |
| `android/build.gradle` | 0/2 | Kotlin/AGP bump, `jvmTarget 17` |
| `android/src/test/.../*.kt` | 6 | Fix failing `getPlatformVersion` test; add permission/thumb tests |
| `ios/Classes/*.swift` | 3 | Deduplicate, authorize every path, async loading, `duration/mimeType`, size without KVC |
| `ios/photo_gallery_pro.podspec` | 0/3 | Version/platform/Swift bump, ship privacy manifest |
| `ios/Resources/PrivacyInfo.xcprivacy` | 3 | Add `NSPrivacyAccessedAPICategory` entries |
| `linux/photo_gallery_pro_plugin.cc` | 4 | Album-contract + media-enumeration fixes, thumbnail unification, extension set, mem discipline |
| `linux/CMakeLists.txt` | 4 | Link `GDK_PIXBUF`, tests target coverage |
| `example/lib/main.dart` | 7 | Cached thumbnail widgets, filter chips, viewer stub |
| `example/**/AndroidManifest.xml`, `Info.plist` | 7 | Permissions + usage descriptions |
| `test/` | 6 | Model/channel/facade unit tests (see §13.1) |
| `README.md`, `CHANGELOG.md`, `MIGRATION.md` | 8 | Version sync, real API docs, error tables |
| `.github/workflows/ci.yml` | 0/6 | analyze + test + native builds + publish dry-run |
| `pubspec.yaml`, `analysis_options.yaml`, `.gitignore` | 0 | Topics, lints, lockfile hygiene |

---

*End of plan. Each phase should land as one or more PRs with the acceptance criteria in §18 checked in the PR template.*
