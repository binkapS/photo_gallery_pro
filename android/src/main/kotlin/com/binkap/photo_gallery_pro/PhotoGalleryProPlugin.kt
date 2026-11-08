package com.binkap.photo_gallery_pro

import android.Manifest
import android.app.Activity
import android.content.ContentUris
import android.content.Context
import android.content.pm.PackageManager
import android.provider.MediaStore
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.graphics.Bitmap
import android.media.ThumbnailUtils
import android.util.Size
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.activity.RequestPermissionsResultListener
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.ByteArrayOutputStream
import java.util.Locale
import java.util.concurrent.Executors

class PhotoGalleryProPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, RequestPermissionsResultListener {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private var pendingPermissionResult: Result? = null
    private var hasRequestedPermission = false
    private val mainHandler: Handler by lazy { Handler(Looper.getMainLooper()) }
    private val thumbnailExecutor = Executors.newFixedThreadPool(2) { task ->
        Thread(task, "photo-gallery-thumbnail").apply { isDaemon = true }
    }
    // Dedicated query executor for album/media listing (kept separate so
    // listing queries don't block thumbnail work).
    private val queryExecutor = Executors.newSingleThreadExecutor { task ->
        Thread(task, "photo-gallery-query").apply { isDaemon = true }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "photo_gallery_pro")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android " + Build.VERSION.SDK_INT)
            }
            "getAlbums" -> {
                val mediaType = call.argument<String?>("mediaType")
                val offset = intArg(call, "offset")
                val limit = intArg(call, "limit")
                handleGetAlbums(mediaType, offset, limit, result)
            }
            "getMediaInAlbum" -> {
                val albumId = call.argument<String>("albumId")
                val mediaType = call.argument<String>("mediaType")
                val offset = intArg(call, "offset")
                val limit = intArg(call, "limit")
                val sort = call.argument<String>("sort")
                if (albumId != null) {
                    handleGetMediaInAlbum(albumId, mediaType ?: "mixed", offset, limit, sort, result)
                } else {
                    result.error("INVALID_ARGUMENTS", "Album ID required", null)
                }
            }
            "getThumbnail" -> {
                val mediaId = call.argument<String>("mediaId")
                val mediaType = call.argument<String>("mediaType")
                val width = intArg(call, "width") ?: 320
                val height = intArg(call, "height") ?: 320
                val format = call.argument<String>("format")
                if (mediaId != null) {
                    thumbnailExecutor.execute {
                        handleGetThumbnail(mediaId, mediaType, width, height, format, result)
                    }
                } else {
                    result.error("INVALID_ARGUMENTS", "Media ID required", null)
                }
            }
            "getAlbumThumbnail" -> {
                val albumId = call.argument<String>("albumId")
                val mediaType = call.argument<String>("mediaType")
                val width = intArg(call, "width") ?: 320
                val height = intArg(call, "height") ?: 320
                val format = call.argument<String>("format")
                if (albumId != null) {
                    thumbnailExecutor.execute {
                        handleGetAlbumThumbnail(albumId, mediaType ?: "mixed", width, height, format, result)
                    }
                } else {
                    result.error("INVALID_ARGUMENTS", "Album ID required", null)
                }
            }
            "getThumbnailBatch" -> {
                val mediaIdsRaw = (call.arguments as? Map<*, *>)?.get("mediaIds") as? List<*>
                if (mediaIdsRaw == null) {
                    result.error("INVALID_ARGUMENTS", "Media IDs required", null)
                    return
                }
                val width = intArg(call, "width") ?: 320
                val height = intArg(call, "height") ?: 320
                val format = call.argument<String>("format")
                val ids = mediaIdsRaw.map { it.toString() }
                thumbnailExecutor.execute {
                    val out = mutableMapOf<String, Map<String, Any>>()
                    for (id in ids) {
                        try {
                            out[id] = createThumbnailMap(id, width, height, format, null)
                        } catch (_: Exception) {
                            // Per spec: omit failures from the result map.
                        }
                    }
                    result.success(out)
                }
            }
            "getOriginalBytes" -> {
                val mediaId = call.argument<String>("mediaId")
                if (mediaId != null) {
                    thumbnailExecutor.execute {
                        try {
                            val bytes = readOriginalBytes(mediaId)
                            result.success(bytes)
                        } catch (e: NotFoundException) {
                            result.error("NOT_FOUND", e.message, null)
                        } catch (e: InvalidTypeException) {
                            result.error("INVALID_TYPE", e.message, null)
                        } catch (e: Exception) {
                            result.error("READ_ERROR", "Error reading original bytes: ${e.message}", e.stackTraceToString())
                        }
                    }
                } else {
                    result.error("INVALID_ARGUMENTS", "Media ID required", null)
                }
            }
            "getPermissionStatus" -> {
                result.success(computePermissionStatus())
            }
            "hasPermission" -> {
                val status = computePermissionStatus()
                result.success(status == "granted" || status == "limited")
            }
            "requestPermission" -> requestPermission(result)
            else -> result.notImplemented()
        }
    }

    // ------------------------------------------------------------------
    // Argument helpers
    // ------------------------------------------------------------------

    private fun intArg(call: MethodCall, name: String): Int? {
        val raw = (call.arguments as? Map<*, *>)?.get(name)
        return (raw as? Number)?.toInt()
    }

    private fun normalizeType(raw: String?): String? = raw?.lowercase(Locale.ROOT)

    private fun formatString(formatRaw: String?): String {
        val n = formatRaw?.lowercase(Locale.ROOT)
        return if (n == "png") "png" else "jpeg"
    }

    private fun postToMain(block: () -> Unit) {
        try {
            mainHandler.post(block)
        } catch (_: Exception) {
            // Unit-test JVMs have no Looper; fall back to a direct call.
            block()
        }
    }

    private fun <T> applyWindow(list: List<T>, offset: Int?, limit: Int?): List<T> {
        val off = (offset ?: 0).coerceAtLeast(0)
        if (off >= list.size) return emptyList()
        val from = off
        val to = if (limit == null) list.size else (from + limit.coerceAtLeast(0)).coerceAtMost(list.size)
        return list.subList(from, to).toList()
    }

    // ------------------------------------------------------------------
    // 1. getAlbums
    // ------------------------------------------------------------------

    private fun handleGetAlbums(mediaTypeRaw: String?, offset: Int?, limit: Int?, result: Result) {
        queryExecutor.execute {
            try {
                val normalized = normalizeType(mediaTypeRaw)
                if (normalized != null && normalized !in setOf("image", "video", "mixed")) {
                    postToMain { result.error("INVALID_TYPE", "Invalid media type: $mediaTypeRaw", null) }
                    return@execute
                }
                val albums = queryAlbums(normalized)
                val windowed = applyWindow(albums, offset, limit)
                postToMain { result.success(windowed) }
            } catch (e: Exception) {
                postToMain { result.error("ALBUMS_ERROR", "Error fetching albums: ${e.message}", e.stackTraceToString()) }
            }
        }
    }

    private data class AlbumAgg(
        val bucketId: String,
        var name: String? = null,
        var imageCount: Int = 0,
        var videoCount: Int = 0,
        var newestImageId: Long? = null,
        var newestImageDate: Long = 0L,
        var newestVideoId: Long? = null,
        var newestVideoDate: Long = 0L,
    )

    private fun queryAlbums(mediaType: String?): List<Map<String, Any>> {
        val agg = mutableMapOf<String, AlbumAgg>()

        fun collect(isVideo: Boolean) {
            if (mediaType == "image" && isVideo) return
            if (mediaType == "video" && !isVideo) return
            val uri = if (isVideo) MediaStore.Video.Media.EXTERNAL_CONTENT_URI else MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            val bucketCol = if (isVideo) MediaStore.Video.Media.BUCKET_ID else MediaStore.Images.Media.BUCKET_ID
            val nameCol = if (isVideo) MediaStore.Video.Media.BUCKET_DISPLAY_NAME else MediaStore.Images.Media.BUCKET_DISPLAY_NAME
            val idCol = if (isVideo) MediaStore.Video.Media._ID else MediaStore.Images.Media._ID
            val dateCol = if (isVideo) MediaStore.Video.Media.DATE_ADDED else MediaStore.Images.Media.DATE_ADDED
            val projection = arrayOf(bucketCol, nameCol, idCol, dateCol)
            context.contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                val bucketIdx = cursor.getColumnIndexOrThrow(bucketCol)
                val nameIdx = cursor.getColumnIndexOrThrow(nameCol)
                val idIdx = cursor.getColumnIndexOrThrow(idCol)
                val dateIdx = cursor.getColumnIndexOrThrow(dateCol)
                while (cursor.moveToNext()) {
                    val bucketId = cursor.getString(bucketIdx) ?: continue
                    val name = cursor.getString(nameIdx)
                    val mediaId = cursor.getLong(idIdx)
                    val dateAdded = cursor.getLong(dateIdx)
                    val entry = agg.getOrPut(bucketId) { AlbumAgg(bucketId) }
                    if (entry.name == null && name != null) entry.name = name
                    if (isVideo) {
                        entry.videoCount++
                        if (dateAdded >= entry.newestVideoDate) {
                            entry.newestVideoDate = dateAdded
                            entry.newestVideoId = mediaId
                        }
                    } else {
                        entry.imageCount++
                        if (dateAdded >= entry.newestImageDate) {
                            entry.newestImageDate = dateAdded
                            entry.newestImageId = mediaId
                        }
                    }
                }
            }
        }

        collect(isVideo = false)
        collect(isVideo = true)

        val out = mutableListOf<Map<String, Any>>()
        for ((bucketId, a) in agg) {
            val type: String
            val count: Int
            val thumbnailId: Long?
            val lastModified: Long
            when (mediaType) {
                "image" -> {
                    if (a.imageCount == 0) continue
                    type = "image"; count = a.imageCount; thumbnailId = a.newestImageId; lastModified = a.newestImageDate
                }
                "video" -> {
                    if (a.videoCount == 0) continue
                    type = "video"; count = a.videoCount; thumbnailId = a.newestVideoId; lastModified = a.newestVideoDate
                }
                else -> {
                    if (a.imageCount == 0 && a.videoCount == 0) continue
                    when {
                        a.imageCount > 0 && a.videoCount > 0 -> {
                            type = "mixed"; count = a.imageCount + a.videoCount
                            if (a.newestImageDate >= a.newestVideoDate) {
                                thumbnailId = a.newestImageId; lastModified = a.newestImageDate
                            } else {
                                thumbnailId = a.newestVideoId; lastModified = a.newestVideoDate
                            }
                        }
                        a.imageCount > 0 -> {
                            type = "image"; count = a.imageCount; thumbnailId = a.newestImageId; lastModified = a.newestImageDate
                        }
                        else -> {
                            type = "video"; count = a.videoCount; thumbnailId = a.newestVideoId; lastModified = a.newestVideoDate
                        }
                    }
                }
            }
            val map = mutableMapOf<String, Any>(
                "id" to bucketId,
                "name" to (a.name ?: "Unknown"),
                "count" to count,
                "type" to type,
            )
            if (thumbnailId != null) map["thumbnailMediaId"] = thumbnailId.toString()
            if (lastModified > 0) map["lastModified"] = lastModified
            out.add(map)
        }
        // Deterministic order: most recently modified album first.
        out.sortWith(compareByDescending<Map<String, Any>> { (it["lastModified"] as? Number)?.toLong() ?: 0L }
            .thenBy { it["name"] as? String ?: "" })
        return out
    }

    // ------------------------------------------------------------------
    // 2. getMediaInAlbum
    // ------------------------------------------------------------------

    private fun handleGetMediaInAlbum(
        albumId: String,
        mediaTypeRaw: String,
        offset: Int?,
        limit: Int?,
        sortRaw: String?,
        result: Result,
    ) {
        queryExecutor.execute {
            try {
                val normalized = normalizeType(mediaTypeRaw)
                if (normalized == null || normalized !in setOf("image", "video", "mixed")) {
                    postToMain { result.error("INVALID_TYPE", "Invalid media type: $mediaTypeRaw", null) }
                    return@execute
                }
                val items = queryMediaInAlbum(albumId, normalized, sortRaw)
                // Slicing a materialized list: for "mixed" we must materialize
                // both tables before windowing anyway, so slicing keeps the
                // single-type path consistent and simple.
                val windowed = applyWindow(items, offset, limit)
                postToMain { result.success(windowed) }
            } catch (e: Exception) {
                postToMain { result.error("FETCH_ERROR", "Failed to fetch media: ${e.message}", e.stackTraceToString()) }
            }
        }
    }

    private fun sortOrderFor(sortRaw: String?): String {
        return when (normalizeType(sortRaw)) {
            "dateaddedasc" -> "${MediaStore.MediaColumns.DATE_ADDED} ASC"
            "nameasc" -> "${MediaStore.MediaColumns.DISPLAY_NAME} ASC"
            "sizedesc" -> "${MediaStore.MediaColumns.SIZE} DESC"
            else -> "${MediaStore.MediaColumns.DATE_ADDED} DESC"
        }
    }

    private fun queryMediaInAlbum(albumId: String, mediaType: String, sortRaw: String?): List<Map<String, Any>> {
        val sortOrder = sortOrderFor(sortRaw)
        val sortNorm = normalizeType(sortRaw)
        if (mediaType == "image") {
            val items = queryMediaTable(albumId, isVideo = false, sortOrder)
            return items
        }
        if (mediaType == "video") {
            val items = queryMediaTable(albumId, isVideo = true, sortOrder)
            return items
        }
        // mixed: query BOTH tables and interleave by sort.
        val images = queryMediaTable(albumId, isVideo = false, sortOrder)
        val videos = queryMediaTable(albumId, isVideo = true, sortOrder)
        val merged = (images + videos).toMutableList()
        when (sortNorm) {
            "dateaddedasc" -> merged.sortBy { (it["dateAdded"] as? Number)?.toLong() ?: 0L }
            "nameasc" -> merged.sortBy { it["name"] as? String ?: "" }
            "sizedesc" -> merged.sortWith(compareByDescending<Map<String, Any>> { (it["size"] as? Number)?.toLong() ?: 0L })
            else -> merged.sortWith(compareByDescending<Map<String, Any>> { (it["dateAdded"] as? Number)?.toLong() ?: 0L })
        }
        return merged
    }

    private fun queryMediaTable(albumId: String, isVideo: Boolean, sortOrder: String): List<Map<String, Any>> {
        val baseUri = if (isVideo) MediaStore.Video.Media.EXTERNAL_CONTENT_URI else MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        val projection = mutableListOf(
            MediaStore.MediaColumns._ID,
            MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.MIME_TYPE,
            MediaStore.MediaColumns.DATE_ADDED,
            MediaStore.MediaColumns.DATE_MODIFIED,
            MediaStore.MediaColumns.SIZE,
            MediaStore.MediaColumns.WIDTH,
            MediaStore.MediaColumns.HEIGHT,
            MediaStore.MediaColumns.BUCKET_ID,
        )
        if (isVideo) {
            projection.add(MediaStore.Video.Media.DURATION)
        }
        // Only pre-Q devices: DATA is deprecated/removed on Q+.
        val includePath = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q
        if (includePath) {
            projection.add(MediaStore.MediaColumns.DATA)
        }
        val out = mutableListOf<Map<String, Any>>()
        context.contentResolver.query(
            baseUri,
            projection.toTypedArray(),
            "${MediaStore.MediaColumns.BUCKET_ID} = ?",
            arrayOf(albumId),
            sortOrder,
        )?.use { cursor ->
            val idIdx = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
            val nameIdx = cursor.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME)
            val mimeIdx = cursor.getColumnIndex(MediaStore.MediaColumns.MIME_TYPE)
            val dateAddedIdx = cursor.getColumnIndex(MediaStore.MediaColumns.DATE_ADDED)
            val dateModifiedIdx = cursor.getColumnIndex(MediaStore.MediaColumns.DATE_MODIFIED)
            val sizeIdx = cursor.getColumnIndex(MediaStore.MediaColumns.SIZE)
            val widthIdx = cursor.getColumnIndex(MediaStore.MediaColumns.WIDTH)
            val heightIdx = cursor.getColumnIndex(MediaStore.MediaColumns.HEIGHT)
            val durationIdx = if (isVideo) cursor.getColumnIndex(MediaStore.Video.Media.DURATION) else -1
            val dataIdx = if (includePath) cursor.getColumnIndex(MediaStore.MediaColumns.DATA) else -1
            while (cursor.moveToNext()) {
                val idLong = cursor.getLong(idIdx)
                val map = mutableMapOf<String, Any>(
                    "id" to idLong.toString(),
                    "uri" to ContentUris.withAppendedId(baseUri, idLong).toString(),
                    "name" to (if (nameIdx >= 0) cursor.getString(nameIdx) ?: "" else ""),
                    "mimeType" to (if (mimeIdx >= 0) cursor.getString(mimeIdx) ?: "" else ""),
                    "type" to if (isVideo) "video" else "image",
                    "dateAdded" to (if (dateAddedIdx >= 0) cursor.getLong(dateAddedIdx) else 0L),
                    "size" to (if (sizeIdx >= 0) cursor.getLong(sizeIdx) else 0L),
                    "width" to (if (widthIdx >= 0) cursor.getInt(widthIdx) else 0),
                    "height" to (if (heightIdx >= 0) cursor.getInt(heightIdx) else 0),
                )
                if (dateModifiedIdx >= 0) {
                    map["dateModified"] = cursor.getLong(dateModifiedIdx)
                }
                if (isVideo && durationIdx >= 0) {
                    map["duration"] = cursor.getLong(durationIdx)
                }
                if (includePath && dataIdx >= 0) {
                    val path = cursor.getString(dataIdx)
                    if (path != null) map["filePath"] = path
                }
                out.add(map)
            }
        }
        return out
    }

    // ------------------------------------------------------------------
    // 3. getThumbnail
    // ------------------------------------------------------------------

    private fun handleGetThumbnail(
        mediaId: String,
        mediaTypeHint: String?,
        width: Int,
        height: Int,
        formatRaw: String?,
        result: Result,
    ) {
        try {
            val map = createThumbnailMap(mediaId, width, height, formatRaw, mediaTypeHint)
            result.success(map)
        } catch (e: NotFoundException) {
            result.error("NOT_FOUND", e.message, null)
        } catch (e: InvalidTypeException) {
            result.error("INVALID_TYPE", e.message, null)
        } catch (e: Exception) {
            result.error("THUMBNAIL_ERROR", "Error generating thumbnail: ${e.message}", e.stackTraceToString())
        }
    }

    private open class PluginException(message: String) : Exception(message)
    private class NotFoundException(message: String) : PluginException(message)
    private class InvalidTypeException(message: String) : PluginException(message)

    private fun mediaExists(mediaId: String, isVideo: Boolean): Boolean {
        val uri = if (isVideo) MediaStore.Video.Media.EXTERNAL_CONTENT_URI else MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        val idCol = if (isVideo) MediaStore.Video.Media._ID else MediaStore.Images.Media._ID
        return context.contentResolver.query(
            uri,
            arrayOf(idCol),
            "$idCol = ?",
            arrayOf(mediaId),
            null,
        )?.use { it.moveToFirst() } ?: false
    }

    private fun resolveMediaKind(mediaId: String, hint: String?): Boolean {
        // Returns true for video, false for image.
        val n = normalizeType(hint)
        if (n != null && n !in setOf("image", "video", "mixed")) {
            throw InvalidTypeException("Invalid media type: $hint")
        }
        if (n == "image") {
            if (mediaExists(mediaId, isVideo = false)) return false
            throw NotFoundException("Image media not found: $mediaId")
        }
        if (n == "video") {
            if (mediaExists(mediaId, isVideo = true)) return true
            throw NotFoundException("Video media not found: $mediaId")
        }
        // Null/absent or "mixed": try images first, then video.
        if (mediaExists(mediaId, isVideo = false)) return false
        if (mediaExists(mediaId, isVideo = true)) return true
        throw NotFoundException("Media not found: $mediaId")
    }

    private fun queryVideoPath(mediaId: String): String? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) return null
        return try {
            context.contentResolver.query(
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                arrayOf(MediaStore.Video.Media.DATA),
                "${MediaStore.Video.Media._ID} = ?",
                arrayOf(mediaId),
                null,
            )?.use { cursor ->
                if (!cursor.moveToFirst()) return null
                val idx = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DATA)
                cursor.getString(idx)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to retrieve video file path: ${e.message}")
            null
        }
    }

    private fun createVideoThumbnailFromPath(videoPath: String?): Bitmap? {
        return if (videoPath != null) {
            ThumbnailUtils.createVideoThumbnail(
                videoPath,
                MediaStore.Video.Thumbnails.MINI_KIND,
            )
        } else {
            null
        }
    }

    private fun loadBitmap(contentUri: Uri, mediaIdLong: Long, isVideo: Boolean, width: Int, height: Int): Bitmap? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                return context.contentResolver.loadThumbnail(contentUri, Size(width, height), null)
            } catch (_: Exception) {
                // fall through to legacy generation
            }
        }
        // Pre-Q (or Q+ fallback).
        return if (isVideo) {
            val path = if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) queryVideoPath(mediaIdLong.toString()) else null
            val thumb = createVideoThumbnailFromPath(path)
            scaleIfNeeded(thumb, width, height)
        } else {
            try {
                val thumb = MediaStore.Images.Thumbnails.getThumbnail(
                    context.contentResolver,
                    mediaIdLong,
                    MediaStore.Images.Thumbnails.MINI_KIND,
                    null,
                )
                scaleIfNeeded(thumb, width, height)
            } catch (_: Exception) {
                null
            }
        }
    }

    private fun scaleIfNeeded(bitmap: Bitmap?, width: Int, height: Int): Bitmap? {
        if (bitmap == null) return null
        if (bitmap.width == width && bitmap.height == height) return bitmap
        return try {
            Bitmap.createScaledBitmap(bitmap, width, height, true)
        } catch (_: Exception) {
            bitmap
        }
    }

    private fun createThumbnailMap(
        mediaId: String,
        width: Int,
        height: Int,
        formatRaw: String?,
        mediaTypeHint: String?,
    ): Map<String, Any> {
        val w = if (width > 0) width else 320
        val h = if (height > 0) height else 320
        val format = formatString(formatRaw)
        // Validate hint before touching ContentResolver so invalid types
        // fail cleanly even without an attached engine (unit tests).
        val hintNorm = normalizeType(mediaTypeHint)
        if (hintNorm != null && hintNorm !in setOf("image", "video", "mixed")) {
            throw InvalidTypeException("Invalid media type: $mediaTypeHint")
        }
        val isVideo = resolveMediaKind(mediaId, mediaTypeHint)
        val baseUri = if (isVideo) MediaStore.Video.Media.EXTERNAL_CONTENT_URI else MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        val mediaIdLong = mediaId.toLongOrNull() ?: throw NotFoundException("Media not found: $mediaId")
        val contentUri = ContentUris.withAppendedId(baseUri, mediaIdLong)
        val bitmap = loadBitmap(contentUri, mediaIdLong, isVideo, w, h)
            ?: throw PluginException("Could not generate thumbnail for $mediaId")
        val stream = ByteArrayOutputStream()
        val compressFormat = if (format == "png") Bitmap.CompressFormat.PNG else Bitmap.CompressFormat.JPEG
        bitmap.compress(compressFormat, 90, stream)
        val bytes = stream.toByteArray()
        if (bytes.isEmpty()) throw PluginException("Could not generate thumbnail for $mediaId")
        return mapOf(
            "data" to bytes,
            "width" to bitmap.width,
            "height" to bitmap.height,
            "format" to format,
        )
    }

    // ------------------------------------------------------------------
    // 4. getAlbumThumbnail
    // ------------------------------------------------------------------

    private fun handleGetAlbumThumbnail(
        albumId: String,
        mediaTypeRaw: String,
        width: Int,
        height: Int,
        formatRaw: String?,
        result: Result,
    ) {
        try {
            val normalized = normalizeType(mediaTypeRaw) ?: "mixed"
            if (normalized !in setOf("image", "video", "mixed")) {
                result.error("INVALID_TYPE", "Invalid media type: $mediaTypeRaw", null)
                return
            }
            val newest = findNewestInAlbum(albumId, normalized)
            if (newest == null) {
                result.error("ALBUM_THUMBNAIL_ERROR", "No media found in album: $albumId", null)
                return
            }
            val map = createThumbnailMap(newest.first, width, height, formatRaw, if (newest.second) "video" else "image")
            result.success(map)
        } catch (e: NotFoundException) {
            result.error("NOT_FOUND", e.message, null)
        } catch (e: InvalidTypeException) {
            result.error("INVALID_TYPE", e.message, null)
        } catch (e: Exception) {
            result.error("ALBUM_THUMBNAIL_ERROR", "Error getting album thumbnail: ${e.message}", e.stackTraceToString())
        }
    }

    private fun findNewestInAlbum(albumId: String, mediaType: String): Pair<String, Boolean>? {
        fun newestFor(isVideo: Boolean): Pair<Long, Long>? {
            val uri = if (isVideo) MediaStore.Video.Media.EXTERNAL_CONTENT_URI else MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            val bucketCol = if (isVideo) MediaStore.Video.Media.BUCKET_ID else MediaStore.Images.Media.BUCKET_ID
            val idCol = if (isVideo) MediaStore.Video.Media._ID else MediaStore.Images.Media._ID
            val dateCol = if (isVideo) MediaStore.Video.Media.DATE_ADDED else MediaStore.Images.Media.DATE_ADDED
            return context.contentResolver.query(
                uri,
                arrayOf(idCol, dateCol),
                "$bucketCol = ?",
                arrayOf(albumId),
                "$dateCol DESC",
            )?.use { cursor ->
                if (!cursor.moveToFirst()) return null
                Pair(cursor.getLong(cursor.getColumnIndexOrThrow(idCol)), cursor.getLong(cursor.getColumnIndexOrThrow(dateCol)))
            }
        }
        if (mediaType == "image") {
            val n = newestFor(isVideo = false) ?: return null
            return Pair(n.first.toString(), false)
        }
        if (mediaType == "video") {
            val n = newestFor(isVideo = true) ?: return null
            return Pair(n.first.toString(), true)
        }
        // mixed: newest across both tables.
        val img = newestFor(isVideo = false)
        val vid = newestFor(isVideo = true)
        if (img == null && vid == null) return null
        if (img == null) return Pair(vid!!.first.toString(), true)
        if (vid == null) return Pair(img.first.toString(), false)
        return if (img.second >= vid.second) Pair(img.first.toString(), false) else Pair(vid.first.toString(), true)
    }

    // ------------------------------------------------------------------
    // 6. getOriginalBytes
    // ------------------------------------------------------------------

    private fun readOriginalBytes(mediaId: String): ByteArray {
        if (mediaExists(mediaId, isVideo = false)) {
            val uri = ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, mediaId.toLongOrNull() ?: throw NotFoundException("Media not found: $mediaId"))
            return context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                ?: throw PluginException("Could not read bytes for $mediaId")
        }
        if (mediaExists(mediaId, isVideo = true)) {
            val uri = ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, mediaId.toLongOrNull() ?: throw NotFoundException("Media not found: $mediaId"))
            return context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                ?: throw PluginException("Could not read bytes for $mediaId")
        }
        throw NotFoundException("Media not found: $mediaId")
    }

    // ------------------------------------------------------------------
    // 7-8. Permissions
    // ------------------------------------------------------------------

    private fun grantCheck(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
    }

    private fun computePermissionStatus(): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val selectedGranted = grantCheck(Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED)
            val imagesGranted = grantCheck(Manifest.permission.READ_MEDIA_IMAGES)
            val videoGranted = grantCheck(Manifest.permission.READ_MEDIA_VIDEO)
            if (selectedGranted) {
                // Full grants also present -> granted.
                if (imagesGranted || videoGranted) return "granted"
                return "limited"
            }
            if (imagesGranted || videoGranted) return "granted"
            return deniedOrPermanent(
                Manifest.permission.READ_MEDIA_IMAGES,
                Manifest.permission.READ_MEDIA_VIDEO,
            )
        } else {
            if (grantCheck(Manifest.permission.READ_EXTERNAL_STORAGE)) return "granted"
            return deniedOrPermanent(Manifest.permission.READ_EXTERNAL_STORAGE)
        }
    }

    private fun deniedOrPermanent(vararg permissions: String): String {
        val act = activity
        val shouldShow = try {
            act?.let { a -> permissions.any { p -> a.shouldShowRequestPermissionRationale(p) } } ?: false
        } catch (_: Exception) {
            false
        }
        return if (hasRequestedPermission && act != null && !shouldShow) "permanentlyDenied" else "denied"
    }

    private fun requestPermission(result: Result) {
        val act = activity
        if (act == null) {
            val status = try {
                computePermissionStatus()
            } catch (_: Exception) {
                "denied"
            }
            result.success(status)
            return
        }
        pendingPermissionResult = result
        hasRequestedPermission = true
        val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            arrayOf(
                Manifest.permission.READ_MEDIA_IMAGES,
                Manifest.permission.READ_MEDIA_VIDEO,
            )
        } else {
            arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        }
        try {
            ActivityCompat.requestPermissions(act, permissions, PERMISSION_REQUEST_CODE)
        } catch (e: Exception) {
            pendingPermissionResult = null
            result.success(computePermissionStatus())
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val r = pendingPermissionResult
            pendingPermissionResult = null
            r?.success(computePermissionStatus())
            return true
        }
        return false
    }

    // Add ActivityAware implementation
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
        val r = pendingPermissionResult
        pendingPermissionResult = null
        r?.success(computePermissionStatus())
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {}

    companion object {
        private const val TAG = "PhotoGalleryProPlugin"
        private const val PERMISSION_REQUEST_CODE = 123
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        thumbnailExecutor.shutdown()
        queryExecutor.shutdown()
    }
}
