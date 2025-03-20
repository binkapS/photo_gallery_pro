import 'package:meta/meta.dart';
import 'package:photo_gallery_pro/src/media_type.dart';

@immutable
abstract class Media {
  final String id;
  final String name;
  final DateTime dateAdded;
  final int size;
  final int width;
  final int height;
  final MediaType type;

  const Media({
    required this.id,
    required this.name,
    required this.dateAdded,
    required this.size,
    required this.width,
    required this.height,
    required this.type,
  });

  factory Media.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String?;
    final type = typeStr == 'image' ? MediaType.image : MediaType.video;

    return type == MediaType.video
        ? VideoMedia.fromJson(json)
        : ImageMedia.fromJson(json);
  }
}

/// Represents an image file
class ImageMedia extends Media {
  const ImageMedia({
    required super.id,
    required super.name,
    required super.dateAdded,
    required super.size,
    required super.width,
    required super.height,
  }) : super(type: MediaType.image);

  factory ImageMedia.fromJson(Map<String, dynamic> json) {
    return ImageMedia(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      dateAdded: DateTime.fromMillisecondsSinceEpoch(
        (json['dateAdded'] as int? ?? 0) * 1000,
      ),
      size: json['size'] as int? ?? 0,
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
    );
  }

  @override
  String toString() => 'ImageMedia(id: $id, name: $name)';
}

/// Represents a video file
class VideoMedia extends Media {
  final Duration duration;

  const VideoMedia({
    required super.id,
    required super.name,
    required super.dateAdded,
    required super.size,
    required super.width,
    required super.height,
    required this.duration,
  }) : super(type: MediaType.video);

  factory VideoMedia.fromJson(Map<String, dynamic> json) {
    return VideoMedia(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
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
  String toString() => 'VideoMedia(id: $id, name: $name, duration: $duration)';
}
