import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../models/reservation.dart';
import '../../models/movie.dart';
import '../../models/showtime.dart';
import '../../services/supabase_service.dart';
import '../../constants/app_constants.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/custom_bottom_nav.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  List<Map<String, dynamic>> _reservations = [];
  bool _isLoading = true;
  String? _error;
  Timer? _timer;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadReservations();

    // Countdown timer - updates every second to show live countdown
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          _error == null &&
          !_isLoading &&
          _reservations.isNotEmpty) {
        _checkExpiredReservations();
        setState(() {}); // Refresh UI to update countdown display
      }
    });

    // Data refresh timer - reload from database every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _error == null) {
        _loadReservations();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// Check for expired reservations and remove them from the list + cleanup in database
  void _checkExpiredReservations() {
    // Don't check if there's an error or still loading
    if (_error != null || _isLoading || _reservations.isEmpty) return;

    final now = DateTime.now();
    final expiredReservations = _reservations.where((item) {
      final reservation = item['reservation'] as Reservation;
      final expiresAt = reservation.expiresAt;
      return expiresAt != null && expiresAt.isBefore(now);
    }).toList();

    if (expiredReservations.isNotEmpty) {
      // Remove expired reservations from local list
      setState(() {
        _reservations.removeWhere((item) {
          final reservation = item['reservation'] as Reservation;
          final expiresAt = reservation.expiresAt;
          return expiresAt != null && expiresAt.isBefore(now);
        });
      });

      // Run cleanup in background to release seats
      SupabaseService.cleanupExpiredReservations();
      SupabaseService.cleanupExpiredSeats();

      print('Auto-removed ${expiredReservations.length} expired reservations');
    }
  }

  Future<void> _loadReservations() async {
    if (!mounted) return; // Don't load if widget is disposed

    // Always show loading and clear error on manual refresh
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('Loading reservations for user: ${user.id}');

      // Load user's reservations (pending and confirmed only, exclude cancelled)
      final reservationsResponse = await SupabaseService.reservations
          .select()
          .eq('user_id', user.id)
          .inFilter('status', ['pending', 'confirmed'])
          .order('created_at', ascending: false);

      print('Found ${reservationsResponse.length} reservations');

      List<Map<String, dynamic>> reservationsWithDetails = [];

      for (var reservationJson in reservationsResponse) {
        final reservation = Reservation.fromJson(reservationJson);

        // Load showtime
        final showtimeResponse = await SupabaseService.showtimes
            .select()
            .eq('id', reservation.showtimeId)
            .single();
        final showtime = Showtime.fromJson(showtimeResponse);

        // Load movie
        final movieResponse = await SupabaseService.movies
            .select()
            .eq('id', showtime.movieId)
            .single();
        final movie = Movie.fromJson(movieResponse);

        reservationsWithDetails.add({
          'reservation': reservation,
          'showtime': showtime,
          'movie': movie,
        });
      }

      if (mounted) {
        setState(() {
          _reservations = reservationsWithDetails;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/dashboard'),
        ),
        title: const Text(
          'My Reservations',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? _buildLoadingSkeleton()
          : _error != null
          ? _buildErrorState()
          : _reservations.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadReservations,
              color: AppConstants.primaryColor,
              backgroundColor: const Color(0xFF1F1F1F),
              child: _buildReservationsList(),
            ),
      bottomNavigationBar: const CustomBottomNav(currentIndex: 2),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) => const ReservationCardSkeleton(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: AppConstants.primaryColor,
            ),
            const SizedBox(height: 24),
            const Text(
              'Failed to load reservations',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: const TextStyle(color: Color(0xFF808080), fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _error = null;
                  _isLoading = true;
                });
                _loadReservations();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_seat_outlined,
            size: 80,
            color: const Color(0xFF808080),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Active Reservations',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Reserve seats to hold them temporarily',
            style: TextStyle(color: Color(0xFF808080), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildReservationsList() {
    return RefreshIndicator(
      color: AppConstants.primaryColor,
      onRefresh: _loadReservations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reservations.length,
        itemBuilder: (context, index) {
          final item = _reservations[index];
          final reservation = item['reservation'] as Reservation;
          final showtime = item['showtime'] as Showtime;
          final movie = item['movie'] as Movie;

          return _buildReservationCard(reservation, showtime, movie);
        },
      ),
    );
  }

  Widget _buildReservationCard(
    Reservation reservation,
    Showtime showtime,
    Movie movie,
  ) {
    final timeRemaining =
        reservation.expiresAt?.difference(DateTime.now()) ?? Duration.zero;
    final isExpired = timeRemaining.isNegative || reservation.expiresAt == null;
    final minutesLeft = timeRemaining.inMinutes;
    final secondsLeft = timeRemaining.inSeconds % 60;

    // Format countdown string
    String countdownText;
    if (isExpired) {
      countdownText = 'EXPIRED';
    } else if (minutesLeft > 0) {
      countdownText = 'EXPIRES IN ${minutesLeft}m ${secondsLeft}s';
    } else {
      countdownText = 'EXPIRES IN ${secondsLeft}s';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpired
              ? Colors.red
              : (minutesLeft < 2 ? Colors.red : Colors.orange),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Header with timer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  (isExpired
                          ? Colors.red
                          : (minutesLeft < 2 ? Colors.red : Colors.orange))
                      .withOpacity(0.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isExpired ? Icons.timer_off : Icons.timer,
                  color: isExpired
                      ? Colors.red
                      : (minutesLeft < 2 ? Colors.red : Colors.orange),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  countdownText,
                  style: TextStyle(
                    color: isExpired
                        ? Colors.red
                        : (minutesLeft < 2 ? Colors.red : Colors.orange),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                Text(
                  reservation.reservationCode ?? 'N/A',
                  style: const TextStyle(
                    color: Color(0xFF808080),
                    fontSize: 10,
                    fontFamily: 'Courier',
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Movie Poster
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: movie.posterUrl ?? '',
                    width: 80,
                    height: 120,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 80,
                      height: 120,
                      color: const Color(0xFF2A2A2A),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 80,
                      height: 120,
                      color: const Color(0xFF2A2A2A),
                      child: const Icon(Icons.movie, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Movie Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        Icons.calendar_today,
                        DateFormat('MMM d, yyyy').format(showtime.showtime),
                      ),
                      const SizedBox(height: 4),
                      _buildDetailRow(
                        Icons.access_time,
                        DateFormat('h:mm a').format(showtime.showtime),
                      ),
                      const SizedBox(height: 4),
                      _buildDetailRow(Icons.location_on, showtime.cinemaHall),
                      const SizedBox(height: 4),
                      _buildDetailRow(
                        Icons.event_seat,
                        '${reservation.seatIds.length} seat${reservation.seatIds.length == 1 ? '' : 's'}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₱${reservation.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _cancelReservation(reservation),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: isExpired
                        ? null
                        : () => _payNow(reservation, showtime),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF2A2A2A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Pay Now',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF808080), size: 14),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _cancelReservation(Reservation reservation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text(
          'Cancel Reservation?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to cancel this reservation? Your seats will be released.',
          style: TextStyle(color: Color(0xFFB3B3B3)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE50914)),
          ),
        ),
      );

      try {
        final totalSeats = reservation.seatIds.length;
        int releasedCount = 0;

        // Release seats FIRST (important!)
        for (var seatId in reservation.seatIds) {
          try {
            await SupabaseService.seats
                .update({
                  'status': 'available',
                  'user_id': null,
                  'reserved_at': null,
                  'paid_at': null,
                })
                .eq('id', seatId);
            releasedCount++;
            print('Released seat $releasedCount of $totalSeats: $seatId');
          } catch (seatError) {
            print('Error releasing seat $seatId: $seatError');
          }
        }

        // Then update reservation status
        await SupabaseService.reservations
            .update({'status': 'cancelled'})
            .eq('id', reservation.id);

        if (mounted) {
          // Close loading dialog
          Navigator.of(context).pop();

          // Reload reservations to update the list
          await _loadReservations();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Reservation cancelled - $releasedCount of $totalSeats seats released',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          // Close loading dialog
          Navigator.of(context).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cancel: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  void _payNow(Reservation reservation, Showtime showtime) {
    // Check if showtime has already started
    final now = DateTime.now();
    if (showtime.showtime.isBefore(now) ||
        showtime.showtime.isAtSameMomentAs(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This showtime has already started and cannot be booked',
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Navigate to payment screen using GoRouter
    final seatIds = reservation.seatIds.join(',');
    context.go('/payment/${showtime.id}?seats=$seatIds');
  }
}
