import 'package:meta/meta.dart';
import 'media_type.dart';

/// Represents a media album (photos or videos)
@immutable
class Album {
  /// Unique identifier for the album
  final String id;

  /// Display name of the album
  final String name;

  /// Number of items in the album
  final int count;

  /// Type of media in the album (image or video)
  final MediaType type;

  const Album({
    required this.id,
    required this.name,
    required this.count,
    required this.type,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      count: json['count'] as int? ?? 0,
      type: json['type'] == 'image' ? MediaType.image : MediaType.video,
    );
  }

  @override
  String toString() => 'Album(name: $name, type: $type, count: $count)';
}
