class Showtime {
  final String id;
  final String movieId;
  final DateTime showtime;
  final String cinemaHall;
  final int totalSeats;
  final double basePrice;
  final DateTime createdAt;

  Showtime({
    required this.id,
    required this.movieId,
    required this.showtime,
    required this.cinemaHall,
    required this.totalSeats,
    required this.basePrice,
    required this.createdAt,
  });

  factory Showtime.fromJson(Map<String, dynamic> json) {
    // Parse showtime - database stores local time without timezone
    final showtimeStr = json['showtime'] as String;
    DateTime parsedShowtime = DateTime.parse(showtimeStr);
    // If parsed as UTC (no timezone in string), treat it as local time
    if (parsedShowtime.isUtc ||
        !showtimeStr.contains('+') && !showtimeStr.contains('Z')) {
      parsedShowtime = DateTime(
        parsedShowtime.year,
        parsedShowtime.month,
        parsedShowtime.day,
        parsedShowtime.hour,
        parsedShowtime.minute,
        parsedShowtime.second,
        parsedShowtime.millisecond,
      );
    }

    return Showtime(
      id: json['id'] as String,
      movieId: json['movie_id'] as String,
      showtime: parsedShowtime,
      cinemaHall: json['cinema_hall'] as String,
      totalSeats: json['total_seats'] as int,
      basePrice: (json['base_price'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'movie_id': movieId,
      'showtime': showtime.toIso8601String(),
      'cinema_hall': cinemaHall,
      'total_seats': totalSeats,
      'base_price': basePrice,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
