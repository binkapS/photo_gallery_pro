import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:photo_gallery_pro/src/media_type.dart';

/// Base class for media items (images and videos) in the gallery.
///
/// This abstract class provides common properties shared between different
/// types of media files like images and videos.
@immutable
abstract class Media {
  /// Unique identifier for the media item
  final String id;

  /// Original filename of the media
  final String name;

  /// Full path to the media file on the device
  final String path;

  /// DateTime when the media was added to the gallery
  final DateTime dateAdded;

  /// File size in bytes
  final int size;

  /// Original width of the media in pixels
  final int width;

  /// Original height of the media in pixels
  final int height;

  /// Type of media (image or video)
  final MediaType type;

  /// Creates a new [Media] instance.
  const Media({
    required this.id,
    required this.name,
    required this.path,
    required this.dateAdded,
    required this.size,
    required this.width,
    required this.height,
    required this.type,
  });

  /// Creates a [Media] instance from a JSON map.
  ///
  /// Returns either an [ImageMedia] or [VideoMedia] based on the type field.
  ///
  /// The JSON map should contain:
  /// - id: String identifier
  /// - name: String filename
  /// - path: String file path
  /// - dateAdded: int (Unix timestamp in seconds)
  /// - size: int (file size in bytes)
  /// - width: int (pixels)
  /// - height: int (pixels)
  /// - type: String ('image' or 'video')
  factory Media.fromJson(Map<String, dynamic> json) {
    final type = json['type'] == 'image' ? MediaType.image : MediaType.video;

    if (type == MediaType.image) {
      return ImageMedia.fromJson(json);
    } else {
      return VideoMedia.fromJson(json);
    }
  }
}

/// Represents an image file in the gallery.
///
/// Contains all properties from [Media] specific to image files.
class ImageMedia extends Media {
  /// Creates a new [ImageMedia] instance.
  const ImageMedia({
    required super.id,
    required super.name,
    required super.path,
    required super.dateAdded,
    required super.size,
    required super.width,
    required super.height,
  }) : super(type: MediaType.image);

  /// Creates an [ImageMedia] instance from a JSON map.
  ///
  /// The JSON map should contain the same fields as [Media.fromJson].
  factory ImageMedia.fromJson(Map<String, dynamic> json) {
    return ImageMedia(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      path: json['path']?.toString() ?? '', // Add path from JSON
      dateAdded: DateTime.fromMillisecondsSinceEpoch(
        (json['dateAdded'] as int? ?? 0) * 1000,
      ),
      size: json['size'] as int? ?? 0,
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
    );
  }

  @override
  String toString() => 'ImageMedia(id: $id, name: $name, path: $path)';
}

/// Represents a video file in the gallery.
///
/// Contains all properties from [Media] plus additional video-specific properties
/// like duration.
class VideoMedia extends Media {
  /// Duration of the video
  final Duration duration;

  /// Creates a new [VideoMedia] instance.
  const VideoMedia({
    required super.id,
    required super.name,
    required super.path,
    required super.dateAdded,
    required super.size,
    required super.width,
    required super.height,
    required this.duration,
  }) : super(type: MediaType.video);

  /// Creates a [VideoMedia] instance from a JSON map.
  ///
  /// The JSON map should contain the same fields as [Media.fromJson] plus:
  /// - duration: int (duration in milliseconds)
  factory VideoMedia.fromJson(Map<String, dynamic> json) {
    return VideoMedia(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      path: json['path']?.toString() ?? '', // Add path from JSON
      dateAdded: DateTime.fromMillisecondsSinceEpoch(
        (json['dateAdded'] as int? ?? 0) * 1000,
      ),
      size: json['size'] as int? ?? 0,
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      duration: Duration(milliseconds: json['duration'] as int? ?? 0),
    );
  }

  @override
  String toString() =>
      'VideoMedia(id: $id, name: $name, path: $path, duration: $duration)';
}
