import 'dart:typed_data';

/// The encoded image format of a [Thumbnail].
enum ThumbnailFormat {
  /// JPEG encoding (default; smallest payload for photos).
  jpeg,

  /// PNG encoding (lossless; larger payloads).
  png,
}

/// The requested pixel dimensions of a [Thumbnail].
///
/// ```dart
/// final thumb = await gallery.getThumbnail(
///   media.id,
///   size: const ThumbnailSize.square(256),
/// );
/// ```
class ThumbnailSize {
  /// Creates a [ThumbnailSize] with the given [width] and [height].
  const ThumbnailSize(this.width, this.height);

  /// Creates a square [ThumbnailSize] of [dimension]×[dimension] pixels.
  const ThumbnailSize.square(int dimension)
    : width = dimension,
      height = dimension;

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThumbnailSize && width == other.width && height == other.height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'ThumbnailSize($width, $height)';
}

/// A decoded thumbnail image for a media item or album.
class Thumbnail {
  /// Creates a [Thumbnail] from its raw [data] bytes and dimensions.
  Thumbnail({
    required this.data,
    this.width = 512,
    this.height = 512,
    this.format = ThumbnailFormat.jpeg,
  });

  /// The encoded image bytes (JPEG by default).
  final Uint8List data;

  /// Pixel width of the thumbnail image.
  final int width;

  /// Pixel height of the thumbnail image.
  final int height;

  /// Whether [data] is JPEG or PNG encoded.
  final ThumbnailFormat format;

  /// Parses a thumbnail from a platform payload.
  ///
  /// Accepts the canonical map shape `{data, width, height, format}` (used by
  /// all platforms), a legacy `{bytes, width, height}` map, or a bare
  /// [Uint8List] (legacy Android payload). An empty or missing byte payload
  /// throws a [FormatException].
  factory Thumbnail.fromPlatformData(dynamic rawData) {
    if (rawData is Uint8List) {
      if (rawData.isEmpty) {
        throw const FormatException('Thumbnail data cannot be empty');
      }
      return Thumbnail(data: rawData);
    }

    if (rawData is Map) {
      final map = Map<String, dynamic>.from(rawData);
      final dynamic rawBytes = map['data'] ?? map['bytes'];
      final Uint8List? data;
      if (rawBytes is Uint8List) {
        data = rawBytes;
      } else if (rawBytes is List<int>) {
        data = Uint8List.fromList(rawBytes);
      } else {
        data = null;
      }
      if (data == null || data.isEmpty) {
        throw const FormatException('Thumbnail data cannot be empty');
      }

      return Thumbnail(
        data: data,
        width: (map['width'] as num?)?.toInt() ?? 512,
        height: (map['height'] as num?)?.toInt() ?? 512,
        format:
            map['format'] == 'png' ? ThumbnailFormat.png : ThumbnailFormat.jpeg,
      );
    }

    throw const FormatException('Invalid thumbnail data format');
  }

  /// Encodes this thumbnail into its canonical platform map shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'data': data,
    'width': width,
    'height': height,
    'format': format.name,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Thumbnail &&
          runtimeType == other.runtimeType &&
          _bytesEqual(data, other.data) &&
          width == other.width &&
          height == other.height &&
          format == other.format;

  @override
  int get hashCode => Object.hash(Object.hashAll(data), width, height, format);

  @override
  String toString() =>
      'Thumbnail(${data.length} bytes, $width×$height, ${format.name})';
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
