import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:typed_data';

/// Supabase Service - Manages database and authentication
class SupabaseService {
  static SupabaseClient? _client;

  /// Initialize Supabase with credentials from .env file
  static Future<void> initialize() async {
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrl == null || supabaseKey == null) {
      throw Exception(
        'Supabase credentials not found in .env file. '
        'Make sure SUPABASE_URL and SUPABASE_ANON_KEY are set.',
      );
    }

    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);

    _client = Supabase.instance.client;
  }

  /// Get the Supabase client instance
  static SupabaseClient get client {
    if (_client == null) {
      throw Exception(
        'Supabase not initialized. Call SupabaseService.initialize() first.',
      );
    }
    return _client!;
  }

  // ============================================
  // Authentication Helpers
  // ============================================

  /// Get the current authenticated user
  static User? get currentUser => client.auth.currentUser;

  /// Check if user is authenticated
  static bool get isAuthenticated => currentUser != null;

  /// Get current user ID
  static String? get userId => currentUser?.id;

  /// Get current user email
  static String? get userEmail => currentUser?.email;

  // ============================================
  // Database Helpers
  // ============================================

  /// Get reference to users table
  static SupabaseQueryBuilder get users => client.from('users');

  /// Get reference to movies table
  static SupabaseQueryBuilder get movies => client.from('movies');

  /// Get reference to showtimes table
  static SupabaseQueryBuilder get showtimes => client.from('showtimes');

  /// Get reference to seats table
  static SupabaseQueryBuilder get seats => client.from('seats');

  /// Get reference to reservations table
  static SupabaseQueryBuilder get reservations => client.from('reservations');

  /// Get reference to tickets table
  static SupabaseQueryBuilder get tickets => client.from('tickets');

  /// Get reference to payment_history table
  static SupabaseQueryBuilder get paymentHistory =>
      client.from('payment_history');

  // ============================================
  // Storage Helpers
  // ============================================

  /// Upload movie poster image to Supabase Storage
  /// Returns the public URL of the uploaded image
  static Future<String> uploadMoviePoster(
    String filePath,
    Uint8List fileBytes,
  ) async {
    try {
      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = filePath.split('.').last;
      final fileName = 'poster_$timestamp.$extension';

      // Upload to Supabase Storage bucket 'movie-posters'
      await client.storage
          .from('movie-posters')
          .uploadBinary(fileName, fileBytes);

      // Get public URL
      final publicUrl = client.storage
          .from('movie-posters')
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload poster: $e');
    }
  }

  /// Delete movie poster from storage
  static Future<void> deleteMoviePoster(String posterUrl) async {
    try {
      // Extract filename from URL
      final uri = Uri.parse(posterUrl);
      final fileName = uri.pathSegments.last;

      await client.storage.from('movie-posters').remove([fileName]);
    } catch (e) {
      throw Exception('Failed to delete poster: $e');
    }
  }

  // ============================================
  // Cleanup Helpers
  // ============================================

  /// Clean up expired reserved seats (15 minutes) and release them
  static Future<int> cleanupExpiredSeats() async {
    try {
      // Calculate 15 minutes ago
      final fifteenMinutesAgo = DateTime.now()
          .toUtc()
          .subtract(const Duration(minutes: 15))
          .toIso8601String();

      print(
        'Cleanup seats: Looking for seats reserved before $fifteenMinutesAgo',
      );

      // Find all seats that were reserved more than 15 minutes ago and are still 'reserved'
      // Also ensure reserved_at is not null
      final expiredSeats = await client
          .from('seats')
          .select('id, reserved_at')
          .eq('status', 'reserved')
          .not('reserved_at', 'is', null)
          .lt('reserved_at', fifteenMinutesAgo);

      if (expiredSeats.isEmpty) {
        print('Cleanup seats: No expired seats found');
        return 0;
      }

      final seatIds = (expiredSeats as List)
          .map((s) => s['id'] as String)
          .toList();

      print('Cleanup seats: Found ${seatIds.length} expired seats to release');

      // Release these expired seats
      await client
          .from('seats')
          .update({
            'status': 'available',
            'user_id': null,
            'reserved_at': null,
            'reservation_expires_at': null,
          })
          .inFilter('id', seatIds);

      print('Released ${seatIds.length} expired reserved seats');
      return seatIds.length;
    } catch (e) {
      print('Error cleaning up expired seats: $e');
      return 0;
    }
  }

  /// Clean up expired reservations and release their seats
  static Future<int> cleanupExpiredReservations() async {
    try {
      final now = DateTime.now().toUtc();
      final nowStr = now.toIso8601String();

      print('Cleanup reservations: Current UTC time: $nowStr');

      // Find all expired pending reservations
      // Only expire if expires_at is NOT null and is in the past
      final expiredReservations = await client
          .from('reservations')
          .select('id, seat_ids, expires_at')
          .eq('status', 'pending')
          .not('expires_at', 'is', null)
          .lt('expires_at', nowStr);

      print(
        'Cleanup reservations: Found ${expiredReservations.length} expired reservations',
      );

      if (expiredReservations.isEmpty) {
        return 0;
      }

      int cleanedCount = 0;

      for (final reservation in expiredReservations) {
        final expiresAt = reservation['expires_at'];
        print(
          'Cleanup: Expiring reservation ${reservation['id']} - expires_at: $expiresAt (current: $nowStr)',
        );

        // Double check - only expire if actually expired
        if (expiresAt != null) {
          try {
            final expiry = DateTime.parse(expiresAt);
            if (expiry.isAfter(now)) {
              print(
                'Skipping reservation ${reservation['id']} - not actually expired',
              );
              continue;
            }
          } catch (e) {
            print('Error parsing expires_at: $e');
            continue;
          }
        }

        final seatIds = List<dynamic>.from(reservation['seat_ids'] ?? []);

        // Release the seats
        if (seatIds.isNotEmpty) {
          await client
              .from('seats')
              .update({
                'status': 'available',
                'user_id': null,
                'reserved_at': null,
                'reservation_expires_at': null,
              })
              .inFilter('id', seatIds);
        }

        // Update reservation status to expired
        await client
            .from('reservations')
            .update({'status': 'cancelled'})
            .eq('id', reservation['id']);

        cleanedCount++;
      }

      return cleanedCount;
    } catch (e) {
      print('Error cleaning up expired reservations: $e');
      return 0;
    }
  }

  /// Clean up expired pending tickets and release their seats
  static Future<int> cleanupExpiredTickets() async {
    try {
      final fifteenMinutesAgo = DateTime.now()
          .toUtc()
          .subtract(const Duration(minutes: 15))
          .toIso8601String();

      // Find all pending tickets that are older than 15 minutes
      // Check both expires_at (if set) and created_at
      final expiredTickets = await client
          .from('tickets')
          .select('id, seat_ids, created_at')
          .eq('payment_status', 'pending')
          .lt('created_at', fifteenMinutesAgo);

      if (expiredTickets.isEmpty) {
        return 0;
      }

      int cleanedCount = 0;

      for (final ticket in expiredTickets) {
        final seatIds = List<dynamic>.from(ticket['seat_ids'] ?? []);

        // Release the seats
        if (seatIds.isNotEmpty) {
          await client
              .from('seats')
              .update({
                'status': 'available',
                'user_id': null,
                'reserved_at': null,
                'paid_at': null,
                'reservation_expires_at': null,
              })
              .inFilter('id', seatIds);
        }

        // Update ticket status to cancelled
        await client
            .from('tickets')
            .update({'status': 'cancelled', 'payment_status': 'expired'})
            .eq('id', ticket['id']);

        cleanedCount++;
        print('Cleaned up expired ticket: ${ticket['id']}');
      }

      return cleanedCount;
    } catch (e) {
      print('Error cleaning up expired tickets: $e');
      return 0;
    }
  }

  /// Run all cleanup tasks
  static Future<Map<String, int>> runCleanupTasks() async {
    final seatsCleaned = await cleanupExpiredSeats();
    final reservationsCleaned = await cleanupExpiredReservations();
    final ticketsCleaned = await cleanupExpiredTickets();

    return {
      'seats': seatsCleaned,
      'reservations': reservationsCleaned,
      'tickets': ticketsCleaned,
    };
  }
}
