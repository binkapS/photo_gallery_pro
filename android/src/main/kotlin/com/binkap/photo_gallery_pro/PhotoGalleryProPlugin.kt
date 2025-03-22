package com.binkap.photo_gallery_pro

import android.Manifest
import android.app.Activity
import android.content.ContentUris
import android.content.Context
import android.content.pm.PackageManager
import android.provider.MediaStore
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.graphics.Bitmap
import android.media.ThumbnailUtils
import android.util.Size
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.ByteArrayOutputStream

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
            "getAlbums" -> {
                val mediaType = call.argument<String?>("mediaType")
                getAlbums(mediaType, result)
            }
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
            "getAlbumThumbnail" -> {
                val albumId = call.argument<String>("albumId")
                val mediaType = call.argument<String>("mediaType")
                if (albumId != null && mediaType != null) {
                    getAlbumThumbnail(albumId, mediaType, result)
                } else {
                    result.error("INVALID_ARGUMENTS", "Album ID and media type required", null)
                }
            }
            "hasPermission" -> checkPermission(result)
            "requestPermission" -> requestPermission(result)
            else -> result.notImplemented()
        }
    }

    private fun getAlbums(mediaType: String?, result: Result) {
        try {
            val albums = mutableListOf<Map<String, Any>>()
            val processedBucketIds = mutableSetOf<String>()

            // Define media URIs based on requested type
            val urisToQuery = when (mediaType) {
                "image" -> listOf(MediaStore.Images.Media.EXTERNAL_CONTENT_URI)
                "video" -> listOf(MediaStore.Video.Media.EXTERNAL_CONTENT_URI)
                null -> listOf(
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                )
                else -> {
                    result.error("INVALID_TYPE", "Invalid media type: $mediaType", null)
                    return
                }
            }

            for (uri in urisToQuery) {
                val isVideo = uri == MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                val (projection, bucketIdColumn, bucketNameColumn) = if (isVideo) {
                    Triple(
                        arrayOf(
                            MediaStore.Video.Media.BUCKET_ID,
                            MediaStore.Video.Media.BUCKET_DISPLAY_NAME,
                            MediaStore.Video.Media._ID
                        ),
                        MediaStore.Video.Media.BUCKET_ID,
                        MediaStore.Video.Media.BUCKET_DISPLAY_NAME
                    )
                } else {
                    Triple(
                        arrayOf(
                            MediaStore.Images.Media.BUCKET_ID,
                            MediaStore.Images.Media.BUCKET_DISPLAY_NAME,
                            MediaStore.Images.Media._ID
                        ),
                        MediaStore.Images.Media.BUCKET_ID,
                        MediaStore.Images.Media.BUCKET_DISPLAY_NAME
                    )
                }

                context.contentResolver.query(
                    uri,
                    projection,
                    null,
                    null,
                    null
                )?.use { cursor ->
                    while (cursor.moveToNext()) {
                        val bucketId = cursor.getString(cursor.getColumnIndexOrThrow(bucketIdColumn))
                        
                        if (bucketId !in processedBucketIds) {
                            processedBucketIds.add(bucketId)
                            
                            val name = cursor.getString(cursor.getColumnIndexOrThrow(bucketNameColumn)) ?: "Unknown"
                            val count = getAlbumCount(bucketId, isVideo)
                            
                            albums.add(mapOf(
                                "id" to bucketId,
                                "name" to name,
                                "count" to count,
                                "type" to if (isVideo) "video" else "image"
                            ))
                        }
                    }
                }
            }

            result.success(albums)
        } catch (e: Exception) {
            result.error("ALBUMS_ERROR", "Error fetching albums: ${e.message}", e.stackTraceToString())
        }
    }

    private fun getMediaInAlbum(albumId: String, mediaType: String, result: Result) {
        try {
            val mediaList = mutableListOf<Map<String, Any>>()
            
            val (uri, projection, selection) = when (mediaType) {
                "image" -> Triple(
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    arrayOf(
                        MediaStore.Images.Media._ID,
                        MediaStore.Images.Media.DISPLAY_NAME,
                        MediaStore.Images.Media.DATE_ADDED,
                        MediaStore.Images.Media.SIZE,
                        MediaStore.Images.Media.WIDTH,
                        MediaStore.Images.Media.HEIGHT
                    ),
                    "${MediaStore.Images.Media.BUCKET_ID} = ?"
                )
                "video" -> Triple(
                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                    arrayOf(
                        MediaStore.Video.Media._ID,
                        MediaStore.Video.Media.DISPLAY_NAME,
                        MediaStore.Video.Media.DATE_ADDED,
                        MediaStore.Video.Media.SIZE,
                        MediaStore.Video.Media.WIDTH,
                        MediaStore.Video.Media.HEIGHT,
                        MediaStore.Video.Media.DURATION
                    ),
                    "${MediaStore.Video.Media.BUCKET_ID} = ?"
                )
                else -> {
                    result.error("INVALID_TYPE", "Invalid media type", null)
                    return
                }
            }

            val cursor = context.contentResolver.query(
                uri,
                projection,
                selection,
                arrayOf(albumId),
                null
            )

            cursor?.use { cursor ->
                while (cursor.moveToNext()) {
                    val media = mutableMapOf<String, Any>()
                    media["id"] = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID))
                    media["name"] = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME))
                    media["dateAdded"] = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_ADDED))
                    media["size"] = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE))
                    media["width"] = cursor.getInt(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.WIDTH))
                    media["height"] = cursor.getInt(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.HEIGHT))
                    media["type"] = mediaType
                    
                    if (mediaType == "video") {
                        media["duration"] = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION))
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
            val (uri, projection, selection) = when (mediaType) {
                "image" -> Triple(
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                   arrayOf(
                        MediaStore.Images.Media._ID,
                        // MediaStore.Images.Media.DATA
                    ),
                   "${MediaStore.Images.Media._ID} = ?"
                )
                "video" -> Triple(
                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                    arrayOf(MediaStore.Video.Media._ID),
                    "${MediaStore.Video.Media._ID} = ?"
                )
                else -> {
                    result.error("INVALID_TYPE", "Invalid media type: $mediaType", null)
                    return
                }
            }

            context.contentResolver.query(
                uri,
                projection,
                selection,
                arrayOf(mediaId),
                null
            )?.use { cursor ->
                if (!cursor.moveToFirst()) {
                    result.error(
                        "THUMBNAIL_ERROR",
                        "${mediaType.capitalize()} media not found: $mediaId",
                        null
                    )
                    return
                }

                val contentUri = ContentUris.withAppendedId(uri, mediaId.toLong())
                
                val thumbnail: Bitmap? = try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        context.contentResolver.loadThumbnail(contentUri, Size(320, 320), null)
                    } else {
                        when (mediaType) {
                            "image" -> MediaStore.Images.Thumbnails.getThumbnail(
                                context.contentResolver,
                                mediaId.toLong(),
                                MediaStore.Images.Thumbnails.MINI_KIND,
                                null
                            )
                            "video" -> ThumbnailUtils.createVideoThumbnail(
                                contentUri.toString(),
                                MediaStore.Video.Thumbnails.MINI_KIND
                            )
                            else -> null
                        }
                    }
                } catch (e: Exception) {
                    // Fallback method if the primary method fails
                    when (mediaType) {
                        "image" -> MediaStore.Images.Thumbnails.getThumbnail(
                            context.contentResolver,
                            mediaId.toLong(),
                            MediaStore.Images.Thumbnails.MINI_KIND,
                            null
                        )
                        "video" -> ThumbnailUtils.createVideoThumbnail(
                            contentUri.toString(),
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
                    result.error(
                        "THUMBNAIL_ERROR",
                        "Could not generate thumbnail for $mediaId",
                        null
                    )
                }
            } ?: run {
                result.error(
                    "THUMBNAIL_ERROR",
                    "Failed to query media content",
                    null
                )
            }
        } catch (e: Exception) {
            result.error(
                "THUMBNAIL_ERROR",
                "Error generating thumbnail: ${e.message}",
                e.stackTraceToString()
            )
        }
    }

    private fun getAlbumThumbnail(albumId: String, mediaType: String, result: Result) {
        try {
            // Determine table and query parameters based on mediaType
            val (uri, projection, selection, sortOrder) = when (mediaType) {
                "image" -> FourTuple(
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    arrayOf(
                        MediaStore.Images.Media._ID,
                        MediaStore.Images.Media.DATE_ADDED
                    ),
                    "${MediaStore.Images.Media.BUCKET_ID} = ?",
                    "${MediaStore.Images.Media.DATE_ADDED} DESC"
                )
                "video" -> FourTuple(
                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                    arrayOf(
                        MediaStore.Video.Media._ID,
                        MediaStore.Video.Media.DATE_ADDED
                    ),
                    "${MediaStore.Video.Media.BUCKET_ID} = ?",
                    "${MediaStore.Video.Media.DATE_ADDED} DESC"
                )
                else -> {
                    result.error("INVALID_TYPE", "Invalid media type: $mediaType", null)
                    return
                }
            }

            context.contentResolver.query(
                uri,
                projection,
                selection,
                arrayOf(albumId),
                sortOrder
            )?.use { cursor ->
                if (!cursor.moveToFirst()) {
                    result.error(
                        "ALBUM_THUMBNAIL_ERROR", 
                        "No media found in album: $albumId", 
                        null
                    )
                    return
                }

                val mediaId = cursor.getString(
                    cursor.getColumnIndexOrThrow(
                        if (mediaType == "image") MediaStore.Images.Media._ID 
                        else MediaStore.Video.Media._ID
                    )
                )

                // Get thumbnail for the most recent media item
                getThumbnail(mediaId, mediaType, result)
            } ?: run {
                result.error(
                    "ALBUM_THUMBNAIL_ERROR",
                    "Failed to query album content",
                    null
                )
            }
        } catch (e: Exception) {
            result.error(
                "ALBUM_THUMBNAIL_ERROR",
                "Error getting album thumbnail: ${e.message}",
                e.stackTraceToString()
            )
        }
    }

    private data class FourTuple<T1, T2, T3, T4>(
        val first: T1,
        val second: T2,
        val third: T3,
        val fourth: T4
    )

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