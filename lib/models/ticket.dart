enum TicketStatus { pending, active, confirmed, used, cancelled }

enum PaymentStatus { pending, paid, failed, expired }

class Ticket {
  final String id;
  final String userId;
  final String? reservationId;
  final String showtimeId;
  final List<String> seatIds;
  final double totalAmount;
  final String paymentMethod;
  final String paymentReference;
  final String qrCodeData;
  final String ticketNumber;
  final TicketStatus status;
  final PaymentStatus paymentStatus;
  final DateTime createdAt;
  final DateTime? usedAt;
  final DateTime reservedAt;
  final DateTime expiresAt;
  final String? paymentMethodId;
  final String? confirmedBy;
  final DateTime? confirmedAt;
  final String? rejectionReason;
  final String? rejectedBy;
  final DateTime? rejectedAt;

  Ticket({
    required this.id,
    required this.userId,
    this.reservationId,
    required this.showtimeId,
    required this.seatIds,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paymentReference,
    required this.qrCodeData,
    required this.ticketNumber,
    required this.status,
    required this.paymentStatus,
    required this.createdAt,
    this.usedAt,
    required this.reservedAt,
    required this.expiresAt,
    this.paymentMethodId,
    this.confirmedBy,
    this.confirmedAt,
    this.rejectionReason,
    this.rejectedBy,
    this.rejectedAt,
  });

  // Helper method to parse UTC datetime strings from database
  static DateTime _parseUtcDateTime(String dateTimeString) {
    final dt = DateTime.parse(dateTimeString);
    // If the datetime doesn't have timezone info, treat it as UTC
    return dt.isUtc
        ? dt
        : DateTime.utc(
            dt.year,
            dt.month,
            dt.day,
            dt.hour,
            dt.minute,
            dt.second,
            dt.millisecond,
            dt.microsecond,
          );
  }

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      reservationId: json['reservation_id'] as String?,
      showtimeId: json['showtime_id'] as String,
      seatIds: (json['seat_ids'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String,
      paymentReference: json['payment_reference'] as String,
      qrCodeData: json['qr_code_data'] as String,
      ticketNumber: json['ticket_number'] as String,
      status: _parseStatus(json['status'] as String),
      paymentStatus: _parsePaymentStatus(json['payment_status'] as String?),
      createdAt: _parseUtcDateTime(json['created_at'] as String),
      usedAt: json['used_at'] != null
          ? _parseUtcDateTime(json['used_at'] as String)
          : null,
      reservedAt: _parseUtcDateTime(
        json['reserved_at'] as String? ?? json['created_at'] as String,
      ),
      expiresAt: _parseUtcDateTime(
        json['expires_at'] as String? ??
            DateTime.now().toUtc().add(Duration(minutes: 15)).toIso8601String(),
      ),
      paymentMethodId: json['payment_method_id'] as String?,
      confirmedBy: json['confirmed_by'] as String?,
      confirmedAt: json['confirmed_at'] != null
          ? _parseUtcDateTime(json['confirmed_at'] as String)
          : null,
      rejectionReason: json['rejection_reason'] as String?,
      rejectedBy: json['rejected_by'] as String?,
      rejectedAt: json['rejected_at'] != null
          ? _parseUtcDateTime(json['rejected_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'reservation_id': reservationId,
      'showtime_id': showtimeId,
      'seat_ids': seatIds,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'payment_reference': paymentReference,
      'qr_code_data': qrCodeData,
      'ticket_number': ticketNumber,
      'status': status.name,
      'payment_status': paymentStatus.name,
      'created_at': createdAt.toIso8601String(),
      'used_at': usedAt?.toIso8601String(),
      'reserved_at': reservedAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'payment_method_id': paymentMethodId,
      'confirmed_by': confirmedBy,
      'confirmed_at': confirmedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'rejected_by': rejectedBy,
      'rejected_at': rejectedAt?.toIso8601String(),
    };
  }

  static TicketStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return TicketStatus.pending;
      case 'active':
        return TicketStatus.active;
      case 'confirmed':
        return TicketStatus.confirmed;
      case 'used':
        return TicketStatus.used;
      case 'cancelled':
        return TicketStatus.cancelled;
      default:
        return TicketStatus.pending;
    }
  }

  static PaymentStatus _parsePaymentStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'paid':
        return PaymentStatus.paid;
      case 'failed':
        return PaymentStatus.failed;
      case 'expired':
        return PaymentStatus.expired;
      default:
        return PaymentStatus.pending;
    }
  }

  bool get isActive =>
      status == TicketStatus.active || status == TicketStatus.confirmed;
  bool get isUsed => status == TicketStatus.used;
  bool get isCancelled => status == TicketStatus.cancelled;
  bool get isPendingApproval => status == TicketStatus.pending;
  bool get isPaid => paymentStatus == PaymentStatus.paid;
  bool get isPending => paymentStatus == PaymentStatus.pending;
  bool get isExpired =>
      paymentStatus == PaymentStatus.expired ||
      expiresAt.isBefore(DateTime.now().toUtc());

  bool get isRejected =>
      paymentStatus == PaymentStatus.failed && rejectionReason != null;

  Duration get timeRemaining {
    final remaining = expiresAt.difference(DateTime.now().toUtc());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  String get formattedTimeRemaining {
    final remaining = timeRemaining;
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
