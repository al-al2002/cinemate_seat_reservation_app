class Movie {
  final String id;
  final String title;
  final String? description;
  final List<String> castMembers;
  final List<String> genre;
  final String language;
  final int durationMinutes;
  final DateTime releaseDate;
  final String? trailerUrl;
  final String? posterUrl;
  final String country;
  final String? rating;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? status;

  Movie({
    required this.id,
    required this.title,
    this.description,
    required this.castMembers,
    required this.genre,
    required this.language,
    required this.durationMinutes,
    required this.releaseDate,
    this.trailerUrl,
    this.posterUrl,
    required this.country,
    this.rating,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.status,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'].toString(),
      title: json['title'] as String,
      description: json['description'] as String?,
      castMembers: _parseCastMembers(json['cast']),
      genre:
          (json['genre'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          [],
      language: json['language'] as String,
      durationMinutes: json['duration_minutes'] as int,
      releaseDate: DateTime.parse(json['release_date'] as String),
      trailerUrl: json['trailer_url'] as String?,
      posterUrl: json['poster_url'] as String?,
      country: json['country'] as String? ?? 'Philippines',
      rating: json['rating']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      status: json['status'] as String?,
    );
  }

  // Helper to parse cast which can be a string or list
  static List<String> _parseCastMembers(dynamic cast) {
    if (cast == null) return [];
    if (cast is List) {
      return cast.map((e) => e.toString()).toList();
    }
    if (cast is String) {
      return cast
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'cast_members': castMembers,
      'genre': genre,
      'language': language,
      'duration_minutes': durationMinutes,
      'release_date': releaseDate.toIso8601String(),
      'trailer_url': trailerUrl,
      'poster_url': posterUrl,
      'country': country,
      'rating': rating,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'status': status,
    };
  }

  String get durationFormatted {
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  bool get isPhilippine => country.toLowerCase() == 'philippines';
}
