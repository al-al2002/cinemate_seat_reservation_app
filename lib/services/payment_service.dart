import 'package:cineme_seat_reservation_app/models/payment_method.dart';
import 'package:cineme_seat_reservation_app/models/ticket.dart';
import 'package:cineme_seat_reservation_app/services/supabase_service.dart';

/// Payment Service - Handles payment operations
class PaymentService {
  /// Fetch all active payment methods
  static Future<List<PaymentMethod>> getPaymentMethods() async {
    try {
      final response = await SupabaseService.client
          .from('payment_methods')
          .select()
          .eq('is_active', true)
          .order('name');

      return (response as List)
          .map((json) => PaymentMethod.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch payment methods: $e');
    }
  }

  /// Create a pending ticket with payment reservation
  static Future<Ticket> createPendingTicket({
    required String userId,
    required String showtimeId,
    required List<String> seatIds,
    required double totalAmount,
    required String paymentMethodId,
  }) async {
    try {
      // Generate reference number using database function
      final refResponse = await SupabaseService.client.rpc(
        'generate_reference_number',
      );
      final paymentReference = refResponse as String;

      // Generate ticket number using database function
      final ticketResponse = await SupabaseService.client.rpc(
        'generate_ticket_number',
      );
      final ticketNumber = ticketResponse as String;

      // Calculate expiry time (15 minutes from now)
      final now = DateTime.now().toUtc();
      final expiresAt = now.add(const Duration(minutes: 15));

      // Create ticket with pending status
      final ticketData = {
        'user_id': userId,
        'showtime_id': showtimeId,
        'seat_ids': seatIds,
        'total_amount': totalAmount,
        'payment_method_id': paymentMethodId,
        'payment_reference': paymentReference,
        'ticket_number': ticketNumber,
        'payment_status': 'pending',
        'status': 'pending',
        'reserved_at': now.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
      };

      final response = await SupabaseService.client
          .from('tickets')
          .insert(ticketData)
          .select()
          .single();

      // Reserve seats with expiry
      await _reserveSeats(seatIds, userId, expiresAt);

      return Ticket.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create pending ticket: $e');
    }
  }

  /// Reserve seats with expiry timestamp
  static Future<void> _reserveSeats(
    List<String> seatIds,
    String userId,
    DateTime expiresAt,
  ) async {
    // First verify the user exists in the users table
    final userExists = await SupabaseService.client
        .from('users')
        .select('id')
        .eq('id', userId)
        .maybeSingle();

    if (userExists == null) {
      throw Exception(
        'User not found in database. Please complete your profile first.',
      );
    }

    for (final seatId in seatIds) {
      await SupabaseService.client
          .from('seats')
          .update({
            'status': 'reserved',
            'user_id': userId,
            'reserved_at': DateTime.now().toUtc().toIso8601String(),
            'reservation_expires_at': expiresAt.toIso8601String(),
          })
          .eq('id', seatId);
    }
  }

  /// Confirm payment (Admin only)
  static Future<void> confirmPayment(
    String ticketId,
    String adminUserId,
  ) async {
    try {
      final now = DateTime.now().toUtc();

      print('Confirming payment for ticket: $ticketId');

      // Update ticket status to 'active' (confirmed)
      await SupabaseService.client
          .from('tickets')
          .update({
            'payment_status': 'paid',
            'status': 'active',
            'confirmed_by': adminUserId,
            'confirmed_at': now.toIso8601String(),
          })
          .eq('id', ticketId);

      // Get ticket to update seats
      final ticketResponse = await SupabaseService.client
          .from('tickets')
          .select('seat_ids')
          .eq('id', ticketId)
          .single();

      final seatIds = List<String>.from(ticketResponse['seat_ids'] ?? []);
      print('Updating ${seatIds.length} seats to paid: $seatIds');

      // Update seats to 'paid' status
      if (seatIds.isNotEmpty) {
        // Use batch update for efficiency
        await SupabaseService.client
            .from('seats')
            .update({
              'status': 'paid',
              'paid_at': now.toIso8601String(),
              'reservation_expires_at': null, // Remove expiry
            })
            .inFilter('id', seatIds);

        print('Successfully updated seats to paid status');
      }
    } catch (e) {
      print('Error confirming payment: $e');
      throw Exception('Failed to confirm payment: $e');
    }
  }

  /// Reject payment (Admin only)
  static Future<void> rejectPayment(
    String ticketId,
    String adminUserId,
    String rejectionReason,
  ) async {
    try {
      // Update ticket status to 'cancelled' with rejection reason
      await SupabaseService.client
          .from('tickets')
          .update({
            'payment_status': 'failed',
            'status': 'cancelled',
            'rejection_reason': rejectionReason,
          })
          .eq('id', ticketId);

      // Get ticket to release seats
      final ticketResponse = await SupabaseService.client
          .from('tickets')
          .select('seat_ids')
          .eq('id', ticketId)
          .single();

      final seatIds = List<String>.from(ticketResponse['seat_ids'] ?? []);

      // Release seats back to available
      for (final seatId in seatIds) {
        await SupabaseService.client
            .from('seats')
            .update({
              'status': 'available',
              'user_id': null,
              'reserved_at': null,
              'reservation_expires_at': null,
            })
            .eq('id', seatId);
      }
    } catch (e) {
      throw Exception('Failed to reject payment: $e');
    }
  }

  /// Release expired seats (can be called manually or via cron)
  static Future<int> releaseExpiredSeats() async {
    try {
      final response = await SupabaseService.client.rpc(
        'release_expired_seats',
      );
      return response as int;
    } catch (e) {
      throw Exception('Failed to release expired seats: $e');
    }
  }

  /// Get pending payments for admin dashboard
  /// This queries the tickets table directly for pending payments
  static Stream<List<Map<String, dynamic>>> getPendingPaymentsStream() {
    return SupabaseService.client
        .from('tickets')
        .stream(primaryKey: ['id'])
        .eq('payment_status', 'pending')
        .order('created_at', ascending: false)
        .asyncMap((tickets) async {
          List<Map<String, dynamic>> pendingPayments = [];

          for (var ticket in tickets) {
            try {
              // Get user info
              final userResponse = await SupabaseService.client
                  .from('users')
                  .select('id, email, full_name, phone_number')
                  .eq('id', ticket['user_id'])
                  .maybeSingle();

              // Get showtime info
              final showtimeResponse = await SupabaseService.client
                  .from('showtimes')
                  .select('id, showtime, cinema_hall, movie_id')
                  .eq('id', ticket['showtime_id'])
                  .maybeSingle();

              String movieTitle = 'Unknown';
              if (showtimeResponse != null) {
                // Get movie info
                final movieResponse = await SupabaseService.client
                    .from('movies')
                    .select('id, title')
                    .eq('id', showtimeResponse['movie_id'])
                    .maybeSingle();
                movieTitle = movieResponse?['title'] ?? 'Unknown';
              }

              pendingPayments.add({
                'ticket_id': ticket['id'],
                'payment_reference': ticket['payment_reference'],
                'ticket_number': ticket['ticket_number'],
                'total_amount': ticket['total_amount'],
                'seat_ids': ticket['seat_ids'],
                'payment_status': ticket['status'],
                'payment_proof_url': ticket['payment_proof_url'],
                'expires_at':
                    ticket['created_at'], // Use created_at as a fallback
                'created_at': ticket['created_at'],
                'user_id': userResponse?['id'],
                'user_email': userResponse?['email'] ?? 'Unknown',
                'user_name': userResponse?['full_name'] ?? 'Unknown',
                'phone_number': userResponse?['phone_number'],
                'movie_id': showtimeResponse?['movie_id'],
                'movie_title': movieTitle,
                'showtime_id': showtimeResponse?['id'],
                'showtime': showtimeResponse?['showtime'],
                'cinema_hall': showtimeResponse?['cinema_hall'] ?? 'Unknown',
                'payment_method_name':
                    ticket['payment_method']?.toString().toUpperCase() ??
                    'Unknown',
              });
            } catch (e) {
              // Skip this ticket if there's an error loading related data
              continue;
            }
          }

          return pendingPayments;
        });
  }

  /// Cancel pending ticket
  static Future<void> cancelPendingTicket(String ticketId) async {
    try {
      // Get ticket to release seats
      final ticketResponse = await SupabaseService.client
          .from('tickets')
          .select('seat_ids')
          .eq('id', ticketId)
          .single();

      final seatIds = List<String>.from(ticketResponse['seat_ids'] ?? []);

      // Update ticket status
      await SupabaseService.client
          .from('tickets')
          .update({'payment_status': 'expired', 'status': 'cancelled'})
          .eq('id', ticketId);

      // Release seats
      for (final seatId in seatIds) {
        await SupabaseService.client
            .from('seats')
            .update({
              'status': 'available',
              'user_id': null,
              'reserved_at': null,
              'reservation_expires_at': null,
            })
            .eq('id', seatId);
      }
    } catch (e) {
      throw Exception('Failed to cancel ticket: $e');
    }
  }

  /// Sync all paid tickets - ensure their seats are marked as 'paid'
  /// This fixes any seats that weren't properly updated when payment was confirmed
  static Future<int> syncPaidTicketSeats() async {
    try {
      // Get all active/paid tickets
      final tickets = await SupabaseService.client
          .from('tickets')
          .select('id, seat_ids, showtime_id')
          .eq('payment_status', 'paid');

      print('Found ${tickets.length} paid tickets to sync');

      int fixedCount = 0;
      final now = DateTime.now().toUtc();

      for (final ticket in tickets) {
        final seatIds = List<String>.from(ticket['seat_ids'] ?? []);
        final showtimeId = ticket['showtime_id'] as String?;

        print(
          'Syncing ticket ${ticket['id']}: ${seatIds.length} seats, showtime: $showtimeId',
        );

        if (seatIds.isNotEmpty) {
          // Update all seats for this ticket to 'paid'
          final result = await SupabaseService.client
              .from('seats')
              .update({
                'status': 'paid',
                'paid_at': now.toIso8601String(),
                'reservation_expires_at': null,
              })
              .inFilter('id', seatIds)
              .select();

          print('Updated ${result.length} seats to paid');
          fixedCount += result.length;
        }
      }

      print('Total synced: $fixedCount seats from paid tickets');
      return fixedCount;
    } catch (e) {
      print('Error syncing paid ticket seats: $e');
      return 0;
    }
  }

  /// Force sync a specific ticket's seats to paid status
  static Future<bool> forceSyncTicketSeats(String ticketId) async {
    try {
      final ticket = await SupabaseService.client
          .from('tickets')
          .select('seat_ids, showtime_id, payment_status')
          .eq('id', ticketId)
          .single();

      if (ticket['payment_status'] != 'paid') {
        print('Ticket $ticketId is not paid, skipping sync');
        return false;
      }

      final seatIds = List<String>.from(ticket['seat_ids'] ?? []);
      final now = DateTime.now().toUtc();

      if (seatIds.isNotEmpty) {
        await SupabaseService.client
            .from('seats')
            .update({
              'status': 'paid',
              'paid_at': now.toIso8601String(),
              'reservation_expires_at': null,
            })
            .inFilter('id', seatIds);

        print('Force synced ${seatIds.length} seats for ticket $ticketId');
        return true;
      }
      return false;
    } catch (e) {
      print('Error force syncing ticket seats: $e');
      return false;
    }
  }
}
