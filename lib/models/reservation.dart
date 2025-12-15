enum ReservationStatus { pending, confirmed, cancelled }

class Reservation {
  final String id;
  final String userId;
  final String showtimeId;
  final List<String> seatIds;
  final double totalAmount;
  final ReservationStatus status;
  final String? reservationCode;
  final DateTime createdAt;
  final DateTime? expiresAt;

  Reservation({
    required this.id,
    required this.userId,
    required this.showtimeId,
    required this.seatIds,
    required this.totalAmount,
    required this.status,
    this.reservationCode,
    required this.createdAt,
    this.expiresAt,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      showtimeId: json['showtime_id'] as String,
      seatIds: (json['seat_ids'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      status: _parseStatus(json['status'] as String),
      reservationCode: json['reservation_code'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'showtime_id': showtimeId,
      'seat_ids': seatIds,
      'total_amount': totalAmount,
      'status': status.name,
      'reservation_code': reservationCode,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
    };
  }

  static ReservationStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return ReservationStatus.confirmed;
      case 'cancelled':
        return ReservationStatus.cancelled;
      default:
        return ReservationStatus.pending;
    }
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isPending => status == ReservationStatus.pending;
  bool get isConfirmed => status == ReservationStatus.confirmed;
  bool get isCancelled => status == ReservationStatus.cancelled;
}
