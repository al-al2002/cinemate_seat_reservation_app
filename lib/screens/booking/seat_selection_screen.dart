import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/movie.dart';
import '../../models/showtime.dart';
import '../../models/seat.dart';
import '../../services/supabase_service.dart';
import '../../services/payment_service.dart';
import '../../constants/app_constants.dart';
import 'package:intl/intl.dart';

class SeatSelectionScreen extends StatefulWidget {
  final String showtimeId;

  const SeatSelectionScreen({super.key, required this.showtimeId});

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  Showtime? _showtime;
  Movie? _movie;
  List<Seat> _seats = [];
  Set<String> _selectedSeatIds = {};
  bool _isReserving = false; // Flag to prevent interference during reservation
  bool _isLoading = true;
  String? _error;
  RealtimeChannel? _seatsSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToSeatUpdates();
  }

  @override
  void dispose() {
    // Cancel subscription BEFORE disposing
    _seatsSubscription?.unsubscribe();
    _seatsSubscription = null;
    super.dispose();
  }

  void _subscribeToSeatUpdates() {
    // Subscribe to real-time changes on the seats table
    _seatsSubscription = SupabaseService.client
        .channel('seats-${widget.showtimeId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'seats',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'showtime_id',
            value: widget.showtimeId,
          ),
          callback: (payload) {
            // Only handle updates if widget is still mounted
            if (mounted) {
              _handleSeatUpdate(payload);
            }
          },
        )
        .subscribe();
  }

  void _handleSeatUpdate(PostgresChangePayload payload) {
    // Double-check mounted state
    if (!mounted) return;

    try {
      final eventType = payload.eventType;
      final newRecord = payload.newRecord;

      setState(() {
        if (eventType == PostgresChangeEvent.insert) {
          // New seat added
          final newSeat = Seat.fromJson(newRecord);
          _seats.add(newSeat);
        } else if (eventType == PostgresChangeEvent.update) {
          // Seat updated (most common - status changes)
          final updatedSeat = Seat.fromJson(newRecord);
          final index = _seats.indexWhere((s) => s.id == updatedSeat.id);
          if (index != -1) {
            _seats[index] = updatedSeat;

            // CRITICAL FIX: Don't remove seats during reservation process!
            if (_isReserving) {
              print('Skipping seat deselection during reservation');
              return;
            }

            // Only remove from selection if it's NOT ours
            final currentUserId = SupabaseService.client.auth.currentUser?.id;
            if (_selectedSeatIds.contains(updatedSeat.id) &&
                (updatedSeat.isReserved || updatedSeat.isPaid) &&
                updatedSeat.userId != currentUserId) {
              print('Removing seat ${updatedSeat.id} - booked by another user');
              // Create a new set to avoid concurrent modification
              final newSelection = Set<String>.from(_selectedSeatIds);
              newSelection.remove(updatedSeat.id);
              _selectedSeatIds = newSelection;
            }
          }
        } else if (eventType == PostgresChangeEvent.delete) {
          // Seat deleted (rare)
          final oldRecord = payload.oldRecord;
          _seats.removeWhere((s) => s.id == oldRecord['id']);
        }
      });
    } catch (e) {
      // Silently catch errors to prevent crashes
      print('Error handling seat update: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Clean up expired reservations before loading seats
      await SupabaseService.runCleanupTasks();

      // Sync paid tickets to ensure seats show correct status
      await PaymentService.syncPaidTicketSeats();

      // Load showtime details
      final showtimeResponse = await SupabaseService.showtimes
          .select()
          .eq('id', widget.showtimeId)
          .single();

      final showtime = Showtime.fromJson(showtimeResponse);

      // Check if showtime has already started
      final now = DateTime.now();
      if (showtime.showtime.isBefore(now) ||
          showtime.showtime.isAtSameMomentAs(now)) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This showtime has already started and cannot be booked',
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Load movie details
      final movieResponse = await SupabaseService.movies
          .select()
          .eq('id', showtime.movieId)
          .single();

      final movie = Movie.fromJson(movieResponse);

      // Load seats for this showtime
      final seatsResponse = await SupabaseService.seats
          .select()
          .eq('showtime_id', widget.showtimeId)
          .order('seat_row')
          .order('seat_number');

      final seats = (seatsResponse as List)
          .map((json) => Seat.fromJson(json))
          .toList();

      setState(() {
        _showtime = showtime;
        _movie = movie;
        _seats = seats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _toggleSeat(Seat seat) {
    // Can't select if already reserved or paid
    if (seat.isReserved || seat.isPaid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This seat is not available'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() {
      if (_selectedSeatIds.contains(seat.id)) {
        _selectedSeatIds.remove(seat.id);
      } else {
        _selectedSeatIds.add(seat.id);
      }
    });
  }

  double _calculateTotal() {
    if (_showtime == null) return 0.0;

    double total = 0.0;
    for (var seatId in _selectedSeatIds) {
      final seat = _seats.firstWhere((s) => s.id == seatId);
      // Base price + seat type premium
      double seatPrice = _showtime!.basePrice;
      if (seat.seatType == SeatType.vip) {
        seatPrice += 100; // VIP +₱100
      } else if (seat.seatType == SeatType.premium) {
        seatPrice += 50; // Premium +₱50
      }
      total += seatPrice;
    }
    return total;
  }

  List<Seat> _getSelectedSeats() {
    return _seats.where((seat) => _selectedSeatIds.contains(seat.id)).toList();
  }

  Future<void> _reserveSeats() async {
    print('===== RESERVE SEATS CLICKED =====');
    print('Selected seat IDs: $_selectedSeatIds');
    print('Number of seats: ${_selectedSeatIds.length}');

    if (_selectedSeatIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select at least one seat'),
          backgroundColor: AppConstants.primaryColor,
        ),
      );
      return;
    }

    // Check if showtime has already started
    if (_showtime != null) {
      final now = DateTime.now();
      if (_showtime!.showtime.isBefore(now) ||
          _showtime!.showtime.isAtSameMomentAs(now)) {
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
    }

    // CRITICAL: Set flag to prevent Realtime callback from interfering!
    setState(() {
      _isReserving = true;
    });

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Generate reference number
      final referenceId = 'RES-${DateTime.now().millisecondsSinceEpoch}';

      // Calculate expiry time (15 minutes from now)
      final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 15));

      // Update seats to reserved status
      for (var seatId in _selectedSeatIds) {
        await SupabaseService.seats
            .update({
              'status': 'reserved',
              'user_id': user.id,
              'reserved_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', seatId);
      }

      // Calculate total with seat type pricing
      final selectedSeats = _seats
          .where((s) => _selectedSeatIds.contains(s.id))
          .toList();
      final total = selectedSeats.fold<double>(0, (sum, seat) {
        double seatPrice = _showtime?.basePrice ?? 0;
        if (seat.seatType == SeatType.vip) {
          seatPrice += 100;
        } else if (seat.seatType == SeatType.premium) {
          seatPrice += 50;
        }
        return sum + seatPrice;
      });

      // Create reservation record
      final reservationData = {
        'user_id': user.id,
        'showtime_id': widget.showtimeId,
        'seat_ids': _selectedSeatIds.toList(),
        'total_amount': total,
        'reservation_code': referenceId,
        'status': 'pending',
        'expires_at': expiresAt.toIso8601String(),
      };

      print(
        'Creating reservation with ${_selectedSeatIds.length} seats: $_selectedSeatIds',
      );
      print('Reservation data: $reservationData');

      await SupabaseService.reservations.insert(reservationData);

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        // Reset the flag
        setState(() {
          _isReserving = false;
        });

        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1F1F1F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Column(
              children: [
                Icon(Icons.check_circle, color: Colors.orange, size: 80),
                const SizedBox(height: 16),
                const Text(
                  'Seats Reserved!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Your seats are reserved for 15 minutes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFB3B3B3), fontSize: 16),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Reference Number',
                        style: TextStyle(
                          color: Color(0xFF808080),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        referenceId,
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Close the dialog first
                    Navigator.of(context).pop();
                    // Navigate to Reservations Screen using GoRouter
                    context.go('/my-reservations');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'View My Reservations',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        // Reset the flag
        setState(() {
          _isReserving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reservation failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _proceedToPayment() {
    if (_selectedSeatIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select at least one seat'),
          backgroundColor: AppConstants.primaryColor,
        ),
      );
      return;
    }

    // Check if showtime has already started
    if (_showtime != null) {
      final now = DateTime.now();
      if (_showtime!.showtime.isBefore(now) ||
          _showtime!.showtime.isAtSameMomentAs(now)) {
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
    }

    // Navigate to payment screen with selected seats as query parameter
    final seatIds = _selectedSeatIds.toList().join(',');
    context.push('/payment/${widget.showtimeId}?seats=$seatIds');
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Select Seats',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Real-time indicator
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
          ? _buildErrorState()
          : _buildContent(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: CircularProgressIndicator(color: AppConstants.primaryColor),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: AppConstants.primaryColor),
          const SizedBox(height: 24),
          const Text(
            'Failed to load seats',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 14),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 200),
          child: Column(
            children: [
              // Movie Info Header
              _buildMovieHeader(),
              const SizedBox(height: 24),

              // Screen Indicator
              _buildScreenIndicator(),
              const SizedBox(height: 32),

              // Seat Grid
              _buildSeatGrid(),
              const SizedBox(height: 24),

              // Legend
              _buildLegend(),
              const SizedBox(height: 24),
            ],
          ),
        ),

        // Bottom Summary Bar
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildMovieHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF1F1F1F),
      child: Row(
        children: [
          // Movie Poster
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              _movie?.posterUrl ?? '',
              width: 60,
              height: 90,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 60,
                  height: 90,
                  color: const Color(0xFF2A2A2A),
                  child: const Icon(Icons.movie, color: Colors.white),
                );
              },
            ),
          ),
          const SizedBox(width: 16),

          // Movie Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _movie?.title ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: AppConstants.primaryColor,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d, h:mm a').format(_showtime!.showtime),
                      style: const TextStyle(
                        color: Color(0xFFB3B3B3),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: AppConstants.primaryColor,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _showtime!.cinemaHall,
                      style: const TextStyle(
                        color: Color(0xFFB3B3B3),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenIndicator() {
    return Column(
      children: [
        Container(
          width: 300,
          height: 4,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                AppConstants.primaryColor,
                Colors.transparent,
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'SCREEN',
          style: TextStyle(
            color: Color(0xFF808080),
            fontSize: 12,
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildSeatGrid() {
    // Group seats by row
    final Map<String, List<Seat>> seatsByRow = {};
    for (var seat in _seats) {
      if (!seatsByRow.containsKey(seat.seatRow)) {
        seatsByRow[seat.seatRow] = [];
      }
      seatsByRow[seat.seatRow]!.add(seat);
    }

    // Sort rows alphabetically
    final sortedRows = seatsByRow.keys.toList()..sort();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: sortedRows.map((row) {
            final rowSeats = seatsByRow[row]!;
            // Sort seats by number
            rowSeats.sort((a, b) => a.seatNumber.compareTo(b.seatNumber));

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Row label
                  SizedBox(
                    width: 20,
                    child: Text(
                      row,
                      style: const TextStyle(
                        color: Color(0xFF808080),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Seats
                  ...rowSeats.map((seat) => _buildSeatWidget(seat)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSeatWidget(Seat seat) {
    Color seatColor;
    IconData seatIcon = Icons.event_seat;
    bool isSelected = _selectedSeatIds.contains(seat.id);

    if (seat.isPaid) {
      seatColor = Colors.green; // Green - Sold/Paid
    } else if (seat.isReserved) {
      seatColor = Colors.red; // Red - Reserved by others
    } else if (isSelected) {
      seatColor = Colors.orange; // Orange - Selected by current user
    } else {
      // Available - show seat type with color
      switch (seat.seatType) {
        case SeatType.vip:
          seatColor = const Color(0xFFFFD700); // Gold - VIP
          break;
        case SeatType.premium:
          seatColor = const Color(0xFFC0C0C0); // Silver - Premium
          break;
        case SeatType.regular:
          seatColor = const Color(0xFF808080); // Grey - Regular
          break;
      }
    }

    return GestureDetector(
      onTap: () => _toggleSeat(seat),
      child: Container(
        margin: const EdgeInsets.all(2),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: seatColor.withOpacity(0.3),
          border: Border.all(color: seatColor, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(seatIcon, color: seatColor, size: 16),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Legend',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildLegendItem(
                const Color(0xFF808080),
                'Regular (₱${_showtime!.basePrice.toStringAsFixed(0)})',
              ),
              _buildLegendItem(const Color(0xFFC0C0C0), 'Premium (+₱50)'),
              _buildLegendItem(const Color(0xFFFFD700), 'VIP (+₱100)'),
              _buildLegendItem(Colors.orange, 'Selected'),
              _buildLegendItem(Colors.red, 'Reserved'),
              _buildLegendItem(Colors.green, 'Sold'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(Icons.event_seat, color: color, size: 12),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final selectedSeats = _getSelectedSeats();
    final total = _calculateTotal();

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Selected seats info
              if (selectedSeats.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selected Seats',
                              style: TextStyle(
                                color: Color(0xFF808080),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              selectedSeats
                                  .map((s) => '${s.seatRow}${s.seatNumber}')
                                  .join(', '),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              color: Color(0xFF808080),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₱${total.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: AppConstants.primaryColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Action buttons - Reserve or Pay
              Row(
                children: [
                  // Reserve Button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: selectedSeats.isEmpty ? null : _reserveSeats,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        disabledForegroundColor: const Color(0xFF808080),
                        side: BorderSide(
                          color: selectedSeats.isEmpty
                              ? const Color(0xFF2A2A2A)
                              : Colors.orange,
                          width: 2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Reserve',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Pay Now Button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: selectedSeats.isEmpty
                          ? null
                          : _proceedToPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF2A2A2A),
                        disabledForegroundColor: const Color(0xFF808080),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        selectedSeats.isEmpty
                            ? 'Select Seats'
                            : 'Pay Now (${selectedSeats.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
