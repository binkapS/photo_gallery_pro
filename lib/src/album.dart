import 'package:meta/meta.dart';

import 'media_type.dart';

/// Represents a media album (a bucket/collection of images and/or videos).
@immutable
class Album {
  /// Creates an [Album].
  const Album({
    required this.id,
    required this.name,
    required this.count,
    required this.type,
    this.thumbnailMediaId,
    this.path,
    this.lastModified,
  });

  /// Opaque platform identifier.
  ///
  /// Android: `MediaStore` bucket ID. iOS: `PHAssetCollection` local
  /// identifier. Linux: directory basename under `~/Pictures`. Treat this
  /// as opaque — never parse or re-construct it.
  final String id;

  /// Display name of the album.
  final String name;

  /// Number of items in the album.
  final int count;

  /// Type of media in the album (image, video, or mixed).
  final MediaType type;

  /// The media id of the album's representative (most recent) item, if the
  /// platform provided one.
  final String? thumbnailMediaId;

  /// Filesystem path of the album directory (Linux only; `null` elsewhere).
  final String? path;

  /// When the most recent item in the album was added.
  final DateTime? lastModified;

  /// Creates an [Album] from a platform map.
  ///
  /// Unknown `type` values throw a [FormatException].
  factory Album.fromJson(Map<String, dynamic> json) {
    final typeName = json['type']?.toString();
    final lastModifiedRaw = json['lastModified'];
    return Album(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      type:
          typeName == null ? MediaType.mixed : MediaTypeX.fromString(typeName),
      thumbnailMediaId: json['thumbnailMediaId']?.toString(),
      path: json['path']?.toString(),
      lastModified:
          lastModifiedRaw is num
              ? DateTime.fromMillisecondsSinceEpoch(
                lastModifiedRaw.toInt() * 1000,
              )
              : null,
    );
  }

  /// Encodes this album into its canonical platform map shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'count': count,
    'type': type.name,
    if (thumbnailMediaId != null) 'thumbnailMediaId': thumbnailMediaId,
    if (path != null) 'path': path,
    if (lastModified != null)
      'lastModified': lastModified!.millisecondsSinceEpoch ~/ 1000,
  };

  /// Creates a copy of this album with the given fields replaced.
  Album copyWith({
    String? id,
    String? name,
    int? count,
    MediaType? type,
    String? thumbnailMediaId,
    String? path,
    DateTime? lastModified,
  }) {
    return Album(
      id: id ?? this.id,
      name: name ?? this.name,
      count: count ?? this.count,
      type: type ?? this.type,
      thumbnailMediaId: thumbnailMediaId ?? this.thumbnailMediaId,
      path: path ?? this.path,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Album &&
          id == other.id &&
          name == other.name &&
          count == other.count &&
          type == other.type &&
          thumbnailMediaId == other.thumbnailMediaId &&
          path == other.path &&
          lastModified == other.lastModified;

  @override
  int get hashCode =>
      Object.hash(id, name, count, type, thumbnailMediaId, path, lastModified);

  @override
  String toString() =>
      'Album(id: $id, name: $name, type: $type, count: $count)';
}
