class Album {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int photoCount;
  final String? coverPhotoUrl;

  const Album({
    required this.id,
    required this.name,
    this.description = '',
    required this.createdAt,
    this.updatedAt,
    this.photoCount = 0,
    this.coverPhotoUrl,
  });

  Album copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? photoCount,
    String? coverPhotoUrl,
  }) {
    return Album(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      photoCount: photoCount ?? this.photoCount,
      coverPhotoUrl: coverPhotoUrl ?? this.coverPhotoUrl,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'photoCount': photoCount,
    'coverPhotoUrl': coverPhotoUrl,
  };

  factory Album.fromJson(Map<String, dynamic> json) => Album(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt:
        json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
    photoCount: json['photoCount'] as int? ?? 0,
    coverPhotoUrl: json['coverPhotoUrl'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Album &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          photoCount == other.photoCount &&
          coverPhotoUrl == other.coverPhotoUrl;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    createdAt,
    updatedAt,
    photoCount,
    coverPhotoUrl,
  );
}
