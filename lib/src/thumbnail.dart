import 'dart:typed_data';

class Thumbnail {
  final Uint8List data;

  const Thumbnail({required this.data});

  factory Thumbnail.fromPlatformData(dynamic platformData) {
    if (platformData is Uint8List) {
      return Thumbnail(data: platformData);
    }
    if (platformData is List<int>) {
      return Thumbnail(data: Uint8List.fromList(platformData));
    }
    throw FormatException(
      'Invalid thumbnail data format: ${platformData.runtimeType}',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Thumbnail &&
          runtimeType == other.runtimeType &&
          data == other.data;

  @override
  int get hashCode => data.hashCode;
}
