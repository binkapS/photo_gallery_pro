class Thumbnail {
  final String id;
  final String imageUrl;
  final String originalImageId;
  final int width;
  final int height;
  final String format;
  final int fileSize;
  final DateTime createdAt;

  const Thumbnail({
    required this.id,
    required this.imageUrl,
    required this.originalImageId,
    required this.width,
    required this.height,
    required this.format,
    required this.fileSize,
    required this.createdAt,
  });

  Thumbnail copyWith({
    String? id,
    String? imageUrl,
    String? originalImageId,
    int? width,
    int? height,
    String? format,
    int? fileSize,
    DateTime? createdAt,
  }) {
    return Thumbnail(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      originalImageId: originalImageId ?? this.originalImageId,
      width: width ?? this.width,
      height: height ?? this.height,
      format: format ?? this.format,
      fileSize: fileSize ?? this.fileSize,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'imageUrl': imageUrl,
    'originalImageId': originalImageId,
    'width': width,
    'height': height,
    'format': format,
    'fileSize': fileSize,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Thumbnail.fromJson(Map<String, dynamic> json) => Thumbnail(
    id: json['id'] as String,
    imageUrl: json['imageUrl'] as String,
    originalImageId: json['originalImageId'] as String,
    width: json['width'] as int,
    height: json['height'] as int,
    format: json['format'] as String,
    fileSize: json['fileSize'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Thumbnail &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          imageUrl == other.imageUrl &&
          originalImageId == other.originalImageId &&
          width == other.width &&
          height == other.height &&
          format == other.format &&
          fileSize == other.fileSize &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    imageUrl,
    originalImageId,
    width,
    height,
    format,
    fileSize,
    createdAt,
  );
}
