enum SeatType { regular, vip, premium }

enum SeatStatus { available, reserved, paid }

class Seat {
  final String id;
  final String showtimeId;
  final String seatRow;
  final int seatNumber;
  final SeatType seatType;
  final double priceMultiplier;
  final SeatStatus status;
  final String? userId;
  final DateTime? reservedAt;
  final DateTime? paidAt;
  final DateTime createdAt;

  Seat({
    required this.id,
    required this.showtimeId,
    required this.seatRow,
    required this.seatNumber,
    required this.seatType,
    required this.priceMultiplier,
    required this.status,
    this.userId,
    this.reservedAt,
    this.paidAt,
    required this.createdAt,
  });

  factory Seat.fromJson(Map<String, dynamic> json) {
    return Seat(
      id: json['id'] as String,
      showtimeId: json['showtime_id'] as String,
      seatRow: json['seat_row'] as String,
      seatNumber: json['seat_number'] as int,
      seatType: _parseSeatType(json['seat_type'] as String),
      priceMultiplier: (json['price_multiplier'] as num).toDouble(),
      status: _parseSeatStatus(json['status'] as String),
      userId: json['user_id'] as String?,
      reservedAt: json['reserved_at'] != null
          ? DateTime.parse(json['reserved_at'] as String)
          : null,
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'showtime_id': showtimeId,
      'seat_row': seatRow,
      'seat_number': seatNumber,
      'seat_type': seatType.name,
      'price_multiplier': priceMultiplier,
      'status': status.name,
      'user_id': userId,
      'reserved_at': reservedAt?.toIso8601String(),
      'paid_at': paidAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  static SeatType _parseSeatType(String type) {
    switch (type.toLowerCase()) {
      case 'vip':
        return SeatType.vip;
      case 'premium':
        return SeatType.premium;
      default:
        return SeatType.regular;
    }
  }

  static SeatStatus _parseSeatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'reserved':
        return SeatStatus.reserved;
      case 'paid':
        return SeatStatus.paid;
      default:
        return SeatStatus.available;
    }
  }

  String get seatLabel => '$seatRow$seatNumber';

  bool get isAvailable => status == SeatStatus.available;
  bool get isReserved => status == SeatStatus.reserved;
  bool get isPaid => status == SeatStatus.paid;
}
