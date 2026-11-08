import 'package:meta/meta.dart';

import 'media_type.dart';

/// Base class for media items (images and videos) in the gallery.
///
/// This abstract class provides common properties shared between different
/// types of media files like images and videos.
@immutable
abstract class Media {
  /// Creates a new [Media] instance.
  const Media({
    required this.id,
    required this.name,
    required this.uri,
    required this.dateAdded,
    required this.size,
    required this.width,
    required this.height,
    required this.type,
    this.mimeType,
    this.dateModified,
    this.dateCreated,
    this.filePath,
    this.latitude,
    this.longitude,
  });

  /// Opaque platform identifier.
  ///
  /// Android: `MediaStore` `_ID` stringified. iOS: `PHAsset` local
  /// identifier. Linux: file basename.
  final String id;

  /// Display filename of the media item.
  final String name;

  /// Platform-native lookup key.
  ///
  /// Android: a `content://media/.../<id>` URI string. iOS: the asset's
  /// local identifier. Linux: the media id. Use this (not [filePath]) to
  /// ask the platform for the item's bytes.
  final String uri;

  /// DateTime when the media was added to the gallery.
  final DateTime dateAdded;

  /// File size in bytes (`0` when the platform cannot provide it).
  final int size;

  /// Original width of the media in pixels.
  final int width;

  /// Original height of the media in pixels.
  final int height;

  /// Type of media (image or video).
  final MediaType type;

  /// MIME type of the media (e.g. `image/jpeg`), when known.
  final String? mimeType;

  /// DateTime of the last modification, when reported by the platform.
  final DateTime? dateModified;

  /// DateTime the media was originally created (e.g. EXIF capture date),
  /// when reported by the platform. Falls back to [dateAdded] via [created]
  /// when unknown.
  final DateTime? dateCreated;

  /// Local filesystem path, only when the file is actually cached locally.
  ///
  /// `null` for cloud-only media (e.g. iCloud) and for scoped-storage
  /// content URIs on Android 10+. Never assume this is the lookup key —
  /// use [uri] instead.
  final String? filePath;

  /// GPS latitude, when the platform exposes it (location permission).
  final double? latitude;

  /// GPS longitude, when the platform exposes it (location permission).
  final double? longitude;

  /// Original filename (alias of [name], kept for documentation parity).
  String get filename => name;

  /// Creation date: [dateCreated] when known, otherwise [dateAdded].
  DateTime get created => dateCreated ?? dateAdded;

  /// Legacy filesystem path.
  ///
  /// Deprecated in favor of [uri] (the platform lookup key) and [filePath]
  /// (the local path when one exists). Returns [filePath] when available,
  /// otherwise [uri].
  @Deprecated('Use uri or filePath instead')
  String get path => filePath ?? uri;

  /// Creates a [Media] instance from a JSON map.
  ///
  /// Returns either an [ImageMedia] or [VideoMedia] based on the type field.
  ///
  /// The JSON map should contain:
  /// - id: String identifier
  /// - name: String filename
  /// - uri: String platform lookup key
  /// - dateAdded: int (Unix timestamp in seconds)
  /// - size: int (file size in bytes)
  /// - width: int (pixels)
  /// - height: int (pixels)
  /// - type: String ('image', 'video', or 'mixed')
  ///
  /// Unknown `type` values throw a [FormatException].
  factory Media.fromJson(Map<String, dynamic> json) {
    final typeName = json['type']?.toString();
    if (typeName == null) {
      throw const FormatException('Media payload is missing "type"');
    }
    final type = MediaTypeX.fromString(typeName);
    if (type == MediaType.mixed) {
      throw const FormatException(
        'A single media item cannot have type "mixed"',
      );
    }
    if (type == MediaType.video) {
      return VideoMedia.fromJson(json);
    }
    return ImageMedia.fromJson(json);
  }

  /// Encodes this media item into its canonical platform map shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'uri': uri,
    'type': type.name,
    'dateAdded': dateAdded.millisecondsSinceEpoch ~/ 1000,
    if (dateModified != null)
      'dateModified': dateModified!.millisecondsSinceEpoch ~/ 1000,
    if (dateCreated != null)
      'dateCreated': dateCreated!.millisecondsSinceEpoch ~/ 1000,
    'size': size,
    'width': width,
    'height': height,
    if (mimeType != null) 'mimeType': mimeType,
    if (filePath != null) 'filePath': filePath,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Media &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          uri == other.uri &&
          dateAdded == other.dateAdded &&
          size == other.size &&
          width == other.width &&
          height == other.height &&
          type == other.type &&
          mimeType == other.mimeType &&
          dateModified == other.dateModified &&
          dateCreated == other.dateCreated &&
          filePath == other.filePath &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    uri,
    dateAdded,
    size,
    width,
    height,
    type,
    mimeType,
    dateModified,
    dateCreated,
    filePath,
    latitude,
    longitude,
  );
}

/// Shared JSON parsing helpers for [Media] subclasses.
DateTime _dateFromSeconds(dynamic value) =>
    DateTime.fromMillisecondsSinceEpoch(((value as num?)?.toInt() ?? 0) * 1000);

/// Parses an optional epoch-seconds timestamp.
DateTime? _optionalDate(dynamic value) =>
    value is num
        ? DateTime.fromMillisecondsSinceEpoch(value.toInt() * 1000)
        : null;

/// Represents an image file in the gallery.
///
/// Contains all properties from [Media] specific to image files.
class ImageMedia extends Media {
  /// Creates an [ImageMedia] instance.
  const ImageMedia({
    required super.id,
    required super.name,
    required super.uri,
    required super.dateAdded,
    required super.size,
    required super.width,
    required super.height,
    super.mimeType,
    super.dateModified,
    super.dateCreated,
    super.filePath,
    super.latitude,
    super.longitude,
  }) : super(type: MediaType.image);

  /// Creates an [ImageMedia] instance from a JSON map.
  ///
  /// The JSON map should contain the same fields as [Media.fromJson].
  factory ImageMedia.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    return ImageMedia(
      id: id,
      name: json['name']?.toString() ?? '',
      uri: json['uri']?.toString() ?? id,
      dateAdded: _dateFromSeconds(json['dateAdded']),
      size: (json['size'] as num?)?.toInt() ?? 0,
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      mimeType: json['mimeType']?.toString(),
      dateModified: _optionalDate(json['dateModified']),
      dateCreated: _optionalDate(json['dateCreated']),
      filePath: json['filePath']?.toString() ?? _legacyPath(json),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  /// Copies this media item with the given fields replaced.
  ImageMedia copyWith({
    String? id,
    String? name,
    String? uri,
    DateTime? dateAdded,
    int? size,
    int? width,
    int? height,
    String? mimeType,
    DateTime? dateModified,
    DateTime? dateCreated,
    String? filePath,
    double? latitude,
    double? longitude,
  }) {
    return ImageMedia(
      id: id ?? this.id,
      name: name ?? this.name,
      uri: uri ?? this.uri,
      dateAdded: dateAdded ?? this.dateAdded,
      size: size ?? this.size,
      width: width ?? this.width,
      height: height ?? this.height,
      mimeType: mimeType ?? this.mimeType,
      dateModified: dateModified ?? this.dateModified,
      dateCreated: dateCreated ?? this.dateCreated,
      filePath: filePath ?? this.filePath,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  String toString() => 'ImageMedia(id: $id, name: $name, uri: $uri)';
}

/// Represents a video file in the gallery.
///
/// Contains all properties from [Media] plus additional video-specific
/// properties like duration.
class VideoMedia extends Media {
  /// Creates a new [VideoMedia] instance.
  const VideoMedia({
    required super.id,
    required super.name,
    required super.uri,
    required super.dateAdded,
    required super.size,
    required super.width,
    required super.height,
    required this.duration,
    super.mimeType,
    super.dateModified,
    super.dateCreated,
    super.filePath,
    super.latitude,
    super.longitude,
  }) : super(type: MediaType.video);

  /// Duration of the video.
  final Duration duration;

  /// Creates a [VideoMedia] instance from a JSON map.
  ///
  /// The JSON map should contain the same fields as [Media.fromJson] plus:
  /// - duration: int (duration in milliseconds)
  factory VideoMedia.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    return VideoMedia(
      id: id,
      name: json['name']?.toString() ?? '',
      uri: json['uri']?.toString() ?? id,
      dateAdded: _dateFromSeconds(json['dateAdded']),
      size: (json['size'] as num?)?.toInt() ?? 0,
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      duration: Duration(
        milliseconds: (json['duration'] as num?)?.toInt() ?? 0,
      ),
      mimeType: json['mimeType']?.toString(),
      dateModified: _optionalDate(json['dateModified']),
      dateCreated: _optionalDate(json['dateCreated']),
      filePath: json['filePath']?.toString() ?? _legacyPath(json),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  /// Copies this media item with the given fields replaced.
  VideoMedia copyWith({
    String? id,
    String? name,
    String? uri,
    DateTime? dateAdded,
    int? size,
    int? width,
    int? height,
    Duration? duration,
    String? mimeType,
    DateTime? dateModified,
    DateTime? dateCreated,
    String? filePath,
    double? latitude,
    double? longitude,
  }) {
    return VideoMedia(
      id: id ?? this.id,
      name: name ?? this.name,
      uri: uri ?? this.uri,
      dateAdded: dateAdded ?? this.dateAdded,
      size: size ?? this.size,
      width: width ?? this.width,
      height: height ?? this.height,
      duration: duration ?? this.duration,
      mimeType: mimeType ?? this.mimeType,
      dateModified: dateModified ?? this.dateModified,
      dateCreated: dateCreated ?? this.dateCreated,
      filePath: filePath ?? this.filePath,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoMedia && super == other && duration == other.duration;

  @override
  int get hashCode => Object.hash(super.hashCode, duration);

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    ...super.toJson(),
    'duration': duration.inMilliseconds,
  };

  @override
  String toString() =>
      'VideoMedia(id: $id, name: $name, uri: $uri, duration: $duration)';
}

/// Reads the legacy `path` key as a fallback for [Media.filePath] so that
/// payloads from platforms that still send `path` (and their `uri`) keep
/// working during the transition.
String? _legacyPath(Map<String, dynamic> json) {
  final path = json['path']?.toString();
  return (path != null && path.isNotEmpty) ? path : null;
}
