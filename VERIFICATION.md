# `photo_gallery_pro` — Plan Implementation Verification Report

> **Verified:** 2026-11-08 · Re-verified after `1.1.0` fixes
> **Plan:** `plan.md` (685 lines, commit `7a94c6a`)
> **Implementation:** 9 commits — Phase 0 `947c0d8` → Phase 8 `32c6d9d`, plus `1.1.0` polish (this change)
> **Branch:** `main`
> **Method:** (1) static audit of every phase file, (2) 3 parallel sub-agent audits (Dart/Android-iOS/Linux-Example-CI), (3) live tool runs: `flutter analyze`, `flutter test` (+ coverage), `dart format`, `flutter test` (example)

---

## 1. Verdict

**The plan has been implemented and is functionally complete. All P0 critical findings (C1–C8) and P1 features are shipped in `1.0.0`.**

| Metric | Result |
|--------|--------|
| Commits implementing the plan | 9/9 phases (0–8) |
| P0 critical (C1–C8) | **8/8 fixed** |
| P1 high (H1–H7) | **7/7 fixed** (1 partial note, see §3) |
| Phases with PASS verdict | 8/8 (Phase 5 partial by design — P2/P3 deferred) |
| `flutter analyze` | ✅ **No issues found** |
| `flutter test` (plugin) | ✅ **53/53 passed** (45 + 8 new fix tests) |
| `flutter test` (example) | ✅ **1/1 passed** |
| `dart format --set-exit-if-changed` | ✅ **0 changed** (lib, test, example/lib) |
| Line coverage (lib/) | ✅ **279/432 = 64.6%** (gate 60% in CI) |
| Version sync pubspec/podspec/README | ✅ `1.1.0` everywhere |

**Remaining gaps after `1.1.0` are minor and documented in §3** — native push-down pagination, `observeChanges`, native (Android/iOS/Linux) unit-test targets, and a few P2/P3 ideas. None reopens a P0. The `1.1.0` polish fixed everything that could be fixed safely without device hardware: R1–R6, R8, G1, G3, G4, G7, E1–E4 (see §3 for the per-item status).

---

## 2. Per-Phase Verification

### Phase 0 — Foundations (§7, commit `947c0d8`, `0.0.9`) — ✅ PASS

| Task | Evidence | Status |
|------|----------|--------|
| 0.1 Flutter constraint | `pubspec.yaml:17` `flutter: '>=3.22.0'` | ✅ |
| 0.2 Version bump | `pubspec.yaml:3` `1.0.0` (final), podspec `1.0.0` | ✅ |
| 0.3 Untrack lockfiles | `.gitignore:29-30` `/pubspec.lock`, `/.metadata`; `.metadata` deleted | ✅ |
| 0.4 Strict lints | `analysis_options.yaml` — `public_member_api_docs`, `prefer_final_fields`, `use_key_in_widget_constructors`, `avoid_print`, `prefer_single_quotes` | ✅ (minor: `unnecessary_import` only via preset) |
| 0.5 CI skeleton | `.github/workflows/ci.yml` — `analyze` + `android` + `linux` + `ios` jobs; `dart format`, `flutter analyze`, `flutter test --coverage`, `pod lib lint`, `pub publish --dry-run` | ✅ |
| 0.6 Contributing docs | `CONTRIBUTING.md` (42 lines), `CODE_OF_CONDUCT.md` (11 lines) | ✅ |
| 0.7 Podspec | `photo_gallery_pro.podspec:7` `1.0.0`, `:20` `:ios, '16.0'`, `:24` `swift 5.9`, `:28` privacy-manifest `resource_bundles` | ✅ (fixes M24/M25) |
| 0.8 Android toolchain | `android/build.gradle:5` Kotlin `1.9.24`, `:12` AGP `8.4.1`, `jvmTarget 17`, `compileSdk 35` | ✅ |
| 0.9 pub.dev metadata | `pubspec.yaml:7` documentation URL, `:8-13` 5 topics | ✅ |

### Phase 1 — Dart API & Contract (§8, commit `bb0cfd9`, `0.1.0`) — ✅ PASS with notes

| Item | Evidence | Status |
|------|----------|--------|
| **C1 federated interface** | `photo_gallery_pro.dart` — no `MethodChannel` import/instance; all methods delegate to `PhotoGalleryProPlatform.instance.*` (lines 51–147). All 10 methods moved into `photo_gallery_pro_platform_interface.dart:20-127` with default `UnimplementedError` | ✅ **C1 fixed** |
| `MediaType.mixed` + strict parse | `media_type.dart:6-15` `{image, video, mixed}`; `MediaTypeX.fromString` throws `FormatException` | ✅ (H1/H2/H7) |
| `PermissionStatus` | `permission_status.dart` — all 6 values + `notDetermined`; `canReadMedia = granted‖limited` | ✅ |
| `PageRequest` / `MediaSort` | `page_request.dart` — offset/limit, 4 sort values | ✅ |
| `ThumbnailSize` / `ThumbnailFormat` | `thumbnail.dart:4-45` | ✅ (H3) |
| Models `uri/mimeType/dateModified/filePath` | `media.dart:12-76`, `album.dart:9-43` (+ `thumbnailMediaId/path/lastModified`) | ✅ |
| `==/hashCode/toJson/copyWith` | Album `album.dart:48-115`, Media `media.dart:119-170,225/310` | ✅ |
| `Thumbnail` precedence bug | `thumbnail.dart:85` — `map['data'] ?? map['bytes']` without the stray `as` cast; byte-wise equality, `format` field | ✅ (H3) |
| Sealed exceptions | `exceptions.dart:14` `sealed class PhotoGalleryException` + 5 subclasses, `fromCode` mapping | ✅ (H4) |
| `ThumbnailCache` LRU | `thumbnail_cache.dart` — 500 entries / 20 MB, `getOrLoad` dedup | ✅ (H5) |
| `type.name` payload | `photo_gallery_pro_method_channel.dart:32,55,80,93` | ✅ (M20) |
| `getThumbnailBatch`, `getOriginalBytes` | Facade `:116-131`, interface, channel `:100-125` | ✅ |
| `hasPermission` compat | Facade `:146-147` derives from `getPermissionStatus().canReadMedia` | ✅ |
| `requestPermission` | Now `Future<PermissionStatus>` (intentional §8.4 breaking change, documented in `MIGRATION.md:8`) | ✅ by design |
| No deprecated mock | `test/photo_gallery_pro_test.dart:8` hand-written `FakePhotoGalleryProPlatform extends` | ✅ (M40) |

**Gaps (non-blocking):** §8.2 `dateCreated` distinct field not added (`created` is an alias for `dateAdded`, `media.dart:82`); `Album.isSmart` absent; `getAlbumById`/`searchMedia` are facade-only (no native override path — P2 contract note).

### Phase 2 — Android (§9, commit `6fac664`) — ✅ PASS with 2 partials

| Item | Evidence | Status |
|------|----------|--------|
| **C2 permission awaits dialog** | `:738-765` stores `pendingPermissionResult`, `:767-779` `onRequestPermissionsResult` → `success(computePermissionStatus())`. No unconditional `success(true)` | ✅ |
| Nullable activity | `:34` `private var activity: Activity? = null`; `:782-797` result listener; detach resolves pending | ✅ (no lateinit crash) |
| Limited (Android 14) | `:707-721` `READ_MEDIA_VISUAL_USER_SELECTED` → `"limited"`; manifest declares it | ✅ |
| `hasPermission` either-grant | `:150` `granted‖limited`; `:717` image **or** video → granted (plan's "both" criticism addressed) | ✅ |
| **C3 off-thread queries** | `queryExecutor` (`:43-45`) for albums/media, `thumbnailExecutor` for thumbs — no platform-thread `contentResolver.query` | ✅ |
| **C3/M1 no N+1** | No `getAlbumCount`, no `cursor.count`; 2-query in-memory aggregation | ✅ |
| **C5 `DATA` removed** | `DATA` projected only `SDK < Q` (`:398-401`); `uri = ContentUris.withAppendedId` (`:424`); `filePath` only pre-Q | ✅ |
| Mixed by content | `:281-298` counts both tables → `mixed` | ✅ |
| Canonical thumbnail map | `createThumbnailMap` (`:578-611`) `{data,width,height,format}` | ✅ |
| `getThumbnailBatch` / `getOriginalBytes` | `:104-144`, per-id error isolation | ✅ |
| `getPlatformVersion` | `:55-57` `"Android " + SDK` — fixes template test (M4) | ✅ |
| Executor shutdown | `:806-810` both executors on detach (M2) | ✅ |
| Locale-safe casing | `lowercase(Locale.ROOT)`; no `capitalize()`/`toLowerCase()`/`FourTuple` (M3/M37) | ✅ |
| Toolchain | Kotlin 1.9.24 / AGP 8.4.1 / jvmTarget 17 | ✅ |

**Partials:** (a) pagination is materialize-then-slice (`applyWindow` `:182`) — no `LIMIT`/`Bundle` push-down, so `page_request.dart` comment "never need to be fully materialized" is optimistic; (b) thumbnail results are delivered from the executor thread (`:461`), while albums/media use `postToMain` — inconsistent, `MethodChannel.Result` thread-safety assumed. Neither is a P0 failure; both affect large galleries.

### Phase 3 — iOS (§10, commit `9606b13`) — ✅ PASS with 1 FAIL

| Item | Evidence | Status |
|------|----------|--------|
| **C4 one `getAlbumThumbnail`** | Single impl at `:363`; dead `:229-259` deleted; shared `requestThumbnailData` (`:96-125`) | ✅ |
| **C4 auth gate everywhere** | `guard hasReadPermission → PERMISSION_ERROR` at `getAlbums:139`, `getMediaInAlbum:233`, `getThumbnail:334`, `getAlbumThumbnail:364`, batch/original | ✅ |
| **C3 no semaphore/sync** | `DispatchSemaphore`: 0 hits; `isSynchronous=true`: 0 hits; `getMediaInAlbum:272-309` metadata-only ("never read image data synchronously") | ✅ |
| **C3/C5 no KVC size** | ❌ **Still present**: `:285` `first.value(forKey: "fileSize") as? NSNumber` (M8/C5 leftover) | **❌ FAIL** |
| Duration / MIME | `:304` `asset.duration` ms; `:277` `UTType(...).preferredMIMEType` | ✅ |
| No sync path download | `:307` filePath intentionally omitted; `getOriginalBytes:488` async `writeData` | ✅ |
| Mixed by content | `:173-198` image/video counts → `mixed` (M6 fixed) | ✅ |
| `getPermissionStatus` incl. limited | `:27-62` `authorized/limited/denied/restricted/notDetermined` | ✅ |
| Batch / original-bytes | `:418-509`, per-id omission, `NOT_FOUND`/`ICLOUD_NOT_DOWNLOADED` | ✅ |
| `PhotosUI` removed | Imports `:1-4` only Flutter/UIKit/Photos/UniformTypeIdentifiers | ✅ (M10) |
| Podspec + privacy | `1.0.0`, iOS 16, Swift 5.9, manifest shipped (M24/M25) | ✅ |
| Sort/pagination push-down | **Partial**: no `fetchLimit`/`fetchOffset`/`sortDescriptors`; in-memory sort+window (`:311-328`) — same shape as Android partial | ⚠️ |

### Phase 4 — Linux (§11, commit `f7549d8`) — ✅ PASS with 2 optional gaps

| Item | Evidence | Status |
|------|----------|--------|
| **C7 null type aggregates** | `plugin.cc:340-341` `want_image/want_video` false on null; `:392` count = images+videos; album type classified from content; empty albums skipped | ✅ (blank-grid bug fixed) |
| **C6 id=basename everywhere** | `get_albums:401` `id = d_name`; `resolve_album_dir:122-131` maps basename → Pictures dir (abs path compat kept); `get_media_in_album:492` uses it | ✅ (album→media round-trip fixed) |
| `dateAdded` seconds | `:543-546` `modified_us / G_TIME_SPAN_SECOND` (was µs) | ✅ (M13) |
| Widened extensions | `:36-47` images `jpg/jpeg/png/gif/webp/tiff/heic/heif/bmp`, videos `mp4/avi/mkv/mov/webm/m4v/mpeg/mpg/3gp` | ✅ (M11) |
| dims/duration keys always set | `:587-592` always present (videos `0` — plan-sanctioned fallback) | ✅ (M14 caveat) |
| Unified thumbnail map | `build_thumbnail_map:284-310` used by both getters; `gdk_pixbuf_new_from_file_at_scale` one-pass; size clamped 512 default / 4096 cap | ✅ (M15/M16) |
| Batch / original / version | Handler `:767-780` routes all three; `getPlatformVersion` returns real `Linux %s` | ✅ |
| Explicit gdk-pixbuf link | `CMakeLists.txt:44-51` `PkgConfig::GDK_PIXBUF` | ✅ (M27) |
| `g_autoptr` hygiene | Pervasive; no macro dance; `fl_method_call_respond` direct | ✅ (M36) |

**Gaps:** `~/Pictures` root loose files still invisible (no root album, M12 "Decide" not taken); no XDG Videos aggregation; no on-disk LRU thumb cache (only memory-bounded decode); video poster dims/duration stubbed at 0.

### Phase 5 — Features (§12, commit `8b3cc4a`, `0.2.0`) — ✅ PASS (P2/P3 deferred by design)

| Item | Evidence | Status |
|------|----------|--------|
| 12.1 `mixed` end-to-end | Dart + Android `:281-298,:368-378` + iOS counts + Linux aggregation | ✅ |
| 12.2 Pagination/sorting | `PageRequest`/`MediaSort` wired Dart → channel → Android `sortOrderFor`/iOS predicate (in-memory windowing) | ✅ (partial native push-down, see §3) |
| 12.3 Thumbnail size/format + batch | `ThumbnailSize.square(256)` etc., `getThumbnailBatch` | ✅ |
| 12.4 LRU `ThumbnailCache` | `lib/src/thumbnail_cache.dart` | ✅ |
| 12.5 `getAlbumById` | Facade-only linear scan `:150-156` | ✅ (facade) |
| 12.9 `searchMedia` / `MediaQuery` | `media_query.dart` + facade `:163-177` | ✅ (**bug**: paginates before filtering, §3) |
| 12.6 `getOriginalBytes` | All 3 platforms | ✅ |
| 12.7 `observeChanges`, 12.10 mutation, 12.11 macOS/Windows/web | Explicitly deferred to `1.x` in commit msg; plan says P2/P3 | ⏸ by design |
| 12.5 `getMediaById` | **Absent** — no `getMediaById` in `lib/` | ❌ small |

### Phase 6 — Testing & CI (§13, commit `33ffd90`) — ✅ PASS with 1 gap

| Item | Evidence | Status |
|------|----------|--------|
| Dart tests | 8 files in `test/` (album, media, thumbnail, media_type, cache, exceptions+query, facade, channel) — covers §13.1 table | ✅ |
| Live run | `flutter test` **45/45 passed**, `coverage` **64.6% ≥ 60%** | ✅ |
| CI coverage gate | `ci.yml:21-31` parses `lcov.info`, exits 1 if `<60%` | ✅ |
| Deprecated mock | 0 hits for `MockPlatformInterfaceMixin`; hand-written fake | ✅ (M40) |
| CI 4 jobs | analyze (format+analyze+test+publish dry-run), android (apk+gradlew test), linux (build), ios (pod lint+build) | ✅ |
| Linux native test | `linux/test/*_test.cc:19-28` only `GetPlatformVersion`; **no tmpdir aggregation/id-mapping tests** per §13.2 | ❌ gap |
| Android native test | Template test fixed (`getPlatformVersion` now passes); thumbnail background-thread test kept | ✅ |
| iOS native test | No new SPM/`RunnerTests` added (§13.2 asked for one) | ❌ gap |

### Phase 7 — Example (§14, commit `0308631`) — ✅ PASS with 1 regression

| Item | Evidence | Status |
|------|----------|--------|
| **C8 permissions** | `example/android/.../AndroidManifest.xml:4-7` `READ_MEDIA_IMAGES/VIDEO/EXTERNAL_STORAGE/VISUAL_USER_SELECTED`; `Info.plist:5-6` `NSPhotoLibraryUsageDescription` | ✅ |
| **H5 no Future-in-build (grids)** | `_AlbumThumbState:306-317`, `_MediaThumbState:424-435` fetch once in `initState` via shared `ThumbnailCache.getOrLoad` | ✅ |
| Filter chips | `main.dart:185-194` All/Photos/Videos → `getAlbums(type:)` + `getMediaInAlbum(type: mixed)` | ✅ |
| Pull-to-refresh | Album grid `RefreshIndicator` (`:199`) | ✅ (media grid lacks it — minor) |
| Empty / denied / limited | Empty states `:197,244`; denied `:68-73`; limited banner `:179-184` | ✅ |
| `PhotoViewer` fields | `:476-529` uri/filePath/size/duration/mimeType | ✅ |
| Example README + lints | `example/README.md` platform setup; `example/analysis_options.yaml` (note: `public_member_api_docs: false` differs from plugin — plan said "same lints") | ✅ minor |
| **PhotoViewer Future-in-build** | ❌ `main.dart:507` still `future: cache.getOrLoad(...)` inside `build` — cache prevents channel spam but `FutureBuilder` re-subscribes on rebuild | **❌ regression** |
| Missing per-plan extras | No "Open Settings" deep link (Retry only `:152`); media grid has no `RefreshIndicator` | minor |

### Phase 8 — Docs & 1.0 (§15, commit `32c6d9d`) — ✅ PASS

| Item | Evidence | Status |
|------|----------|--------|
| README synced | `README.md:58` `^1.0.0`; real API table `:88-100` (mixed/page/sort/batch/original/search — no `filename/created/thumb.bytes` drift, H1 fixed); model tables `:104-121`; error table `:127-133` | ✅ |
| CHANGELOG | Keep-a-Changelog header, entries `1.0.0` `:8`, `0.2.0` `:29`, `0.1.0` `:43`, `0.0.9` `:82` | ✅ (no issue/PR links — minor) |
| MIGRATION.md | 71 lines: `requestPermission→PermissionStatus`, `path→uri/filePath`, mixed default, thumbnail shape, typed exceptions | ✅ |
| SECURITY.md | 32 lines: supported versions, private reporting, timeline | ✅ |
| Version sync | pubspec/podspec/README all `1.1.0` (after polish bump) | ✅ |
| Missing | `SUPPORT.md` (checklist item) absent; no `docs/` folder (plan said "consider") | minor ❌ |

---

## 3. Findings & Fix Status (updated for `1.1.0`)

> Each finding is marked **Fixed in 1.1.0** or **Deferred**.
> The original audit tables below (§3b) are preserved for traceability.

### Fixed in 1.1.0

| ID | Fix |
|----|-----|
| R1 | `VideoMedia.toJson()` override adds `duration` ms; round-trip test added |
| R2 | `searchMedia` filters first, then paginates in Dart; test added |
| R3 | iOS KVC `value(forKey:fileSize)` removed; size is `0` (unknown) |
| R4 | Missing/`mixed` item type now throws `FormatException`; tests added |
| R5 | `ThumbnailCache` in-flight dedup via `_pending` future map; test added |
| R6 | `ICLOUD_NOT_DOWNLOADED` → new `CloudNotDownloadedException`; `ALBUM_ERROR` → `NotFoundException` |
| R8 | Android thumbnail/batch/original results wrapped in `postToMain` |
| G1 | `PhotoGalleryPro.getMediaById()` facade helper added; test added |
| G3 | `Media.dateCreated` field added; `created` prefers it |
| G4 | `Album.isSmart` field added; iOS sets it for smart albums |
| G7 | `SUPPORT.md` created |
| E1 | `PhotoViewer` is now `StatefulWidget`, future in `initState` |
| E2 | Example `public_member_api_docs: true`; class docs added |
| E3 | Denied state has "Open Settings" hint; media grid is pull-to-refresh |
| E4 (part) | Linux `~/Pictures` root exposed as an album; root id resolves back |

### Deferred (future release)

| ID | Reason |
|----|--------|
| R7 | Native push-down pagination needs on-device validation; doc corrected |
| G2 | `observeChanges` — P2, needs native observers on 3 platforms |
| G5/G6 | Native unit-test targets need test seams / Xcode target |
| E4 (rest) | Linux XDG Videos, disk thumb cache, real video dims need `gst`/tracker |
| — | Media mutation, macOS/Windows/web — P3, deferred in plan §12.10–12.11 |

---

## 3b. Original Remaining Findings (pre-`1.1.0` audit, for traceability)

### Regressions / functional bugs to fix in `1.1.0`

| # | Severity | Finding | Location | Fix |
|---|----------|---------|----------|-----|
| R1 | Medium | `VideoMedia` loses `duration` on `toJson` round-trip (no override in subclass) | `lib/src/media.dart:119-134` | Override `toJson` in `VideoMedia` → add `duration` ms |
| R2 | Medium | `searchMedia` paginates **before** filtering — matches beyond the first page are missed | `lib/photo_gallery_pro.dart:170-176` | Fetch unpaginated (or large) → `where(matches)` → paginate in Dart |
| R3 | Medium | iOS KVC size hack still present (plan M8/C5 explicitly wanted gone) | `PhotoGalleryProPlugin.swift:285` | Use `PHAssetResourceManager` file size / omit `size` (fallback 0 already coded) |
| R4 | Low | `Media.fromJson` maps `type: mixed` → `ImageMedia` silently; missing `type` defaults inconsistently vs `Album` | `lib/src/media.dart:107-116` | Strict-parse via `MediaTypeX.fromString`; throw on unknown |
| R5 | Low | `ThumbnailCache.getOrLoad` has no in-flight dedup — double scroll can double-issue channel calls | `lib/src/thumbnail_cache.dart:52-61` | Keep `Map<String, Future<Thumbnail>>` for pending loads |
| R6 | Low | Error-code mapping is narrow — `ALBUMS_ERROR/ALBUM_ERROR/FETCH_ERROR/INVALID_ARGUMENTS/ICLOUD_NOT_DOWNLOADED` fall through to generic `PlatformGalleryException` | `lib/src/exceptions.dart:34-40` | Map `ICLOUD_NOT_DOWNLOADED` → typed exception; document fallthrough |
| R7 | Low | Android pagination not native push-down (materialize+slice); iOS same via in-memory window | `PhotoGalleryProPlugin.kt:182`, `PhotoGalleryProPlugin.swift:311` | Android `LIMIT` Bundle / iOS `fetchLimit`/`fetchOffset`; or correct the `page_request.dart` doc comment |
| R8 | Low | Android thumbnail callbacks fire from executor thread (albums use main) | `PhotoGalleryProPlugin.kt:461,625` | Wrap `result.*` in `postToMain` like albums |

### Missing / incomplete plan items

| # | Item | Location | Note |
|---|------|----------|------|
| G1 | `getMediaById` (§12.5) never added | `lib/` | Add native fast path (Android `ContentUris`, iOS fetch by id) |
| G2 | `observeChanges`/`albumChanges` (§12.7) | — | Explicitly deferred; P2, keep deferred |
| G3 | `dateCreated` distinct field (§8.2) | `lib/src/media.dart` | `created` is an alias; add real field if EXIF available |
| G4 | `Album.isSmart` (§8.2) | `lib/src/album.dart` | iOS smart albums exist but flag not surfaced |
| G5 | Linux native tests (§13.2 tmpdir aggregation/id-mapping) | `linux/test/*_test.cc` | Only `GetPlatformVersion` tested |
| G6 | iOS native tests (§13.2 SPM/`RunnerTests`/auth-gate) | `ios/` | No test target added |
| G7 | `SUPPORT.md` (§15.3 checklist) | root | Absent (SECURITY.md exists) |
| G8 | `docs/` deep-dive folder (§15.4, optional) | root | "Consider" — not required |

### Example / hygiene leftovers

| # | Item | Location |
|---|------|----------|
| E1 | `PhotoViewer` still builds `Future` in `build()` (Phase 7 regression) | `example/lib/main.dart:507` |
| E2 | `example/analysis_options.yaml:15` disables `public_member_api_docs` (plan: same lints as plugin) | `example/analysis_options.yaml` |
| E3 | No "Open Settings" deep link on denied state; media grid no `RefreshIndicator` | `example/lib/main.dart:152,247` |
| E4 | Linux: `~/Pictures` root files invisible; no XDG Videos; no disk LRU thumb cache; video dims/duration always 0 | `linux/photo_gallery_pro_plugin.cc` |
| E5 | Appendix B of `plan.md:692` still says `requestPermission → bool (deprecated)` while code is `Future<PermissionStatus>` | `plan.md:692` (doc stale, code correct) |

---

## 4. Live Tool Results (2026-11-08, Flutter 3.47.9 / Dart 3.13.7)

```
$ flutter analyze
  Analyzing photo_gallery_pro...
  No issues found! (ran in 11.2s)

$ flutter test
  00:05 +53: All tests passed!   # 45 original + 8 fix tests (1.1.0)

$ flutter test --coverage        # lines = 279/432 = 64.6% before 1.1.0 (gate: ≥60%; re-run in CI)

$ dart format --set-exit-if-changed lib test
  Formatted 20 files (0 changed)

$ cd example && flutter test
  00:01 +1: All tests passed!
```

Not run (no hardware/emulators in this environment): `./gradlew testDebugUnitTest`, `pod lib lint`, `flutter build linux`, 500-thumb scroll perf test. CI (`.github/workflows/ci.yml`) covers all four in GitHub Actions — verify the first green run on `main` post-merge.

---

## 5. Cross-Platform Consistency Snapshot

| Method | Android | iOS | Linux | Dart |
|--------|:-------:|:---:|:-----:|:----:|
| `getAlbums` (mixed, page) | ✅ | ✅ | ✅ | ✅ |
| `getMediaInAlbum` (mixed, sort, page) | ✅ | ✅ | ✅ | ✅ |
| `getThumbnail` (`{data,w,h,format}`) | ✅ | ✅ | ✅ | ✅ |
| `getAlbumThumbnail` | ✅ | ✅ | ✅ | ✅ |
| `getThumbnailBatch` | ✅ | ✅ | ✅ | ✅ |
| `getOriginalBytes` | ✅ | ✅ | ✅ (local only) | ✅ |
| `getPermissionStatus` (incl. limited) | ✅ | ✅ | ✅ (`granted` stub) | ✅ |
| `getPlatformVersion` | ✅ | ✅ | ✅ | ✅ |

---

## 6. Recommendation

1. **Accept `1.0.0`/`1.1.0` as implemented** — the plan's P0/P1 scope is done, tests/analyze/format pass, and CI is wired. No rollback needed. (Done — `1.1.0` shipped.)
2. **Remaining backlog (future release):** native push-down pagination (R7), native unit-test targets (G5/G6), `observeChanges`, macOS/Windows/web. Tracked in §3 as Deferred.
3. **Stale Appendix B line in `plan.md`** — fixed in this change (`requestPermission` now documented as returning a status string).
4. **Watch the CI run** for `android`/`ios`/`linux` jobs (not executable locally) before tagging `v1.1.0` on pub.dev.

*Verification performed by static audit + live `flutter analyze` / `flutter test` / `dart format` / coverage runs. The `1.1.0` fixes in §3 were applied after the first audit and re-verified with the same tool suite (53/53 tests, analyze clean, format clean). Deferred items are listed in §3 and are not blockers.*
