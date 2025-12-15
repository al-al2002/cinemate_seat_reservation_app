class Review {
  final String id;
  final String userId;
  final String movieId;
  final int rating;
  final String? reviewText;
  final String? userName;
  final String? userEmail;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.userId,
    required this.movieId,
    required this.rating,
    this.reviewText,
    this.userName,
    this.userEmail,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      movieId: json['movie_id'].toString(),
      rating: json['rating'] as int,
      reviewText: json['review_text'] as String?,
      userName: json['user_name'] as String?,
      userEmail: json['user_email'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'movie_id': movieId,
      'rating': rating,
      'review_text': reviewText,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get displayName {
    if (userName != null && userName!.isNotEmpty) {
      return userName!;
    }
    if (userEmail != null && userEmail!.isNotEmpty) {
      return userEmail!.split('@')[0]; // Use email prefix
    }
    return 'Anonymous';
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${difference.inDays > 730 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${difference.inDays > 60 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}
