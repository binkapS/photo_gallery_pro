import 'dart:typed_data';

class Thumbnail {
  final Uint8List data;
  final int width;
  final int height;

  Thumbnail({
    required this.data,
    this.width = 512,  // Default size for backward compatibility
    this.height = 512,
  });

  factory Thumbnail.fromPlatformData(dynamic rawData) {
    // Handle direct Uint8List (Android)
    if (rawData is Uint8List) {
      return Thumbnail(data: rawData);
    }
    
    // Handle Map format (iOS/Linux)
    if (rawData is Map) {
      final map = Map<String, dynamic>.from(rawData);
      final data = map['data'] ?? map['bytes'] as Uint8List?;
      if (data == null || data.isEmpty) {
        throw FormatException('Thumbnail data cannot be empty');
      }
      
      return Thumbnail(
        data: data,
        width: map['width'] as int? ?? 512,
        height: map['height'] as int? ?? 512,
      );
    }

    throw FormatException('Invalid thumbnail data format');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Thumbnail &&
          runtimeType == other.runtimeType &&
          data == other.data &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => data.hashCode ^ width.hashCode ^ height.hashCode;
}
