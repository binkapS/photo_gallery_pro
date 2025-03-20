package com.binkap.photo_gallery_pro

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.provider.MediaStore
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.graphics.Bitmap
import android.media.ThumbnailUtils
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class PhotoGalleryProPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var activity: Activity

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "photo_gallery_pro")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getAlbums" -> getAlbums(result)
            "getMediaInAlbum" -> {
                val albumId = call.argument<String>("albumId")
                val mediaType = call.argument<String>("mediaType") // "image" or "video"
                if (albumId != null && mediaType != null) {
                    getMediaInAlbum(albumId, mediaType, result)
                } else {
                    result.error("INVALID_ARGUMENTS", "Album ID and media type required", null)
                }
            }
            "getThumbnail" -> {
                val mediaId = call.argument<String>("mediaId")
                val mediaType = call.argument<String>("mediaType")
                if (mediaId != null && mediaType != null) {
                    getThumbnail(mediaId, mediaType, result)
                } else {
                    result.error("INVALID_ARGUMENTS", "Media ID and type required", null)
                }
            }
            "hasPermission" -> checkPermission(result)
            "requestPermission" -> requestPermission(result)
            else -> result.notImplemented()
        }
    }

    private fun getAlbums(result: Result) {
        val albums = mutableListOf<Map<String, Any>>()
        
        // Query for image albums
        var imageProjection = arrayOf(
            MediaStore.Images.Media.BUCKET_ID,
            MediaStore.Images.Media.BUCKET_DISPLAY_NAME,
            "COUNT(*) AS count"
        )
        
        val imageSelection = "1) GROUP BY (${MediaStore.Images.Media.BUCKET_ID}"
        
        val imageCursor = context.contentResolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            imageProjection,
            imageSelection,
            null,
            null
        )

        imageCursor?.use { cursor ->
            while (cursor.moveToNext()) {
                val album = mapOf(
                    "id" to cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Images.Media.BUCKET_ID)),
                    "name" to cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Images.Media.BUCKET_DISPLAY_NAME)),
                    "count" to cursor.getInt(cursor.getColumnIndexOrThrow("count")),
                    "type" to "image"
                )
                albums.add(album)
            }
        }

        // Query for video albums
        var videoProjection = arrayOf(
            MediaStore.Video.Media.BUCKET_ID,
            MediaStore.Video.Media.BUCKET_DISPLAY_NAME,
            "COUNT(*) AS count"
        )
        
        val videoSelection = "1) GROUP BY (${MediaStore.Video.Media.BUCKET_ID}"
        
        val videoCursor = context.contentResolver.query(
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
            videoProjection,
            videoSelection,
            null,
            null
        )

        videoCursor?.use { cursor ->
            while (cursor.moveToNext()) {
                val album = mapOf(
                    "id" to cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Video.Media.BUCKET_ID)),
                    "name" to cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Video.Media.BUCKET_DISPLAY_NAME)),
                    "count" to cursor.getInt(cursor.getColumnIndexOrThrow("count")),
                    "type" to "video"
                )
                albums.add(album)
            }
        }

        result.success(albums)
    }

    private fun getMediaInAlbum(albumId: String, mediaType: String, result: Result) {
        try {
            val mediaList = mutableListOf<Map<String, Any>>()
            
            val uri = when (mediaType) {
                "image" -> MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                "video" -> MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                else -> {
                    result.error("INVALID_TYPE", "Invalid media type", null)
                    return
                }
            }

            val projection = when (mediaType) {
                "image" -> arrayOf(
                    MediaStore.Images.Media._ID,
                    MediaStore.Images.Media.DISPLAY_NAME,
                    MediaStore.Images.Media.DATE_ADDED,
                    MediaStore.Images.Media.SIZE,
                    MediaStore.Images.Media.WIDTH,
                    MediaStore.Images.Media.HEIGHT
                )
                "video" -> arrayOf(
                    MediaStore.Video.Media._ID,
                    MediaStore.Video.Media.DISPLAY_NAME,
                    MediaStore.Video.Media.DATE_ADDED,
                    MediaStore.Video.Media.SIZE,
                    MediaStore.Video.Media.WIDTH,
                    MediaStore.Video.Media.HEIGHT,
                    MediaStore.Video.Media.DURATION
                )
                else -> arrayOf()
            }

            val selection = when (mediaType) {
                "image" -> "${MediaStore.Images.Media.BUCKET_ID} = ?"
                "video" -> "${MediaStore.Video.Media.BUCKET_ID} = ?"
                else -> ""
            }

            val cursor = context.contentResolver.query(
                uri,
                projection,
                selection,
                arrayOf(albumId),
                null
            )

            cursor?.use {
                while (it.moveToNext()) {
                    val media = mutableMapOf<String, Any>()
                    media["id"] = it.getString(it.getColumnIndexOrThrow(MediaStore.MediaColumns._ID))
                    media["name"] = it.getString(it.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME))
                    media["dateAdded"] = it.getLong(it.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_ADDED))
                    media["size"] = it.getLong(it.getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE))
                    media["width"] = it.getInt(it.getColumnIndexOrThrow(MediaStore.MediaColumns.WIDTH))
                    media["height"] = it.getInt(it.getColumnIndexOrThrow(MediaStore.MediaColumns.HEIGHT))
                    
                    if (mediaType == "video") {
                        media["duration"] = it.getLong(it.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION))
                    }
                    
                    mediaList.add(media)
                }
            }

            result.success(mediaList)
        } catch (e: Exception) {
            result.error(
                "FETCH_ERROR",
                "Failed to fetch media: ${e.message}",
                e.stackTraceToString()
            )
        }
    }

    private fun getThumbnail(mediaId: String, mediaType: String, result: Result) {
        try {
            val uri = when (mediaType) {
                "image" -> ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, mediaId.toLong())
                "video" -> ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, mediaId.toLong())
                else -> {
                    result.error("INVALID_TYPE", "Invalid media type", null)
                    return
                }
            }

            val thumbnail = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                context.contentResolver.loadThumbnail(uri, Size(320, 320), null)
            } else {
                when (mediaType) {
                    "image" -> MediaStore.Images.Thumbnails.getThumbnail(
                        context.contentResolver,
                        mediaId.toLong(),
                        MediaStore.Images.Thumbnails.MINI_KIND,
                        null
                    )
                    "video" -> ThumbnailUtils.createVideoThumbnail(
                        uri.toString(),
                        MediaStore.Video.Thumbnails.MINI_KIND
                    )
                    else -> null
                }
            }

            if (thumbnail != null) {
                val stream = ByteArrayOutputStream()
                thumbnail.compress(Bitmap.CompressFormat.JPEG, 90, stream)
                result.success(stream.toByteArray())
            } else {
                result.error("THUMBNAIL_ERROR", "Could not generate thumbnail", null)
            }
        } catch (e: Exception) {
            result.error("THUMBNAIL_ERROR", e.message, null)
        }
    }

    private fun checkPermission(result: Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val hasImagePermission = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.READ_MEDIA_IMAGES
            ) == PackageManager.PERMISSION_GRANTED
            
            val hasVideoPermission = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.READ_MEDIA_VIDEO
            ) == PackageManager.PERMISSION_GRANTED
            
            result.success(hasImagePermission && hasVideoPermission)
        } else {
            val hasStoragePermission = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.READ_EXTERNAL_STORAGE
            ) == PackageManager.PERMISSION_GRANTED
            
            result.success(hasStoragePermission)
        }
    }

    private fun requestPermission(result: Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(
                    Manifest.permission.READ_MEDIA_IMAGES,
                    Manifest.permission.READ_MEDIA_VIDEO
                ),
                PERMISSION_REQUEST_CODE
            )
        } else {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE),
                PERMISSION_REQUEST_CODE
            )
        }
        result.success(true)
    }

    // Add ActivityAware implementation
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {}
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }
    override fun onDetachedFromActivityForConfigChanges() {}

    companion object {
        private const val PERMISSION_REQUEST_CODE = 123
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}