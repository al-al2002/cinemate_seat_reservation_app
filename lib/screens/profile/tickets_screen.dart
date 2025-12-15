import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../models/ticket.dart';
import '../../models/movie.dart';
import '../../models/showtime.dart';
import '../../services/supabase_service.dart';
import '../../constants/app_constants.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/custom_bottom_nav.dart';
import '../ticket/ticket_screen.dart';
import 'package:intl/intl.dart';

enum TicketFilter { all, upcoming, active, past }

// Helper enum for ticket timing status
enum TicketTimingStatus { upcoming, active, past }

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  List<Map<String, dynamic>> _allTickets = [];
  List<Map<String, dynamic>> _filteredTickets = [];
  bool _isLoading = true;
  String? _error;
  TicketFilter _currentFilter = TicketFilter.upcoming;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Load user's tickets
      final ticketsResponse = await SupabaseService.tickets
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> ticketsWithDetails = [];

      for (var ticketJson in ticketsResponse) {
        final ticket = Ticket.fromJson(ticketJson);

        // Load showtime
        final showtimeResponse = await SupabaseService.showtimes
            .select()
            .eq('id', ticket.showtimeId)
            .single();
        final showtime = Showtime.fromJson(showtimeResponse);

        // Load movie
        final movieResponse = await SupabaseService.movies
            .select()
            .eq('id', showtime.movieId)
            .single();
        final movie = Movie.fromJson(movieResponse);

        ticketsWithDetails.add({
          'ticket': ticket,
          'showtime': showtime,
          'movie': movie,
        });
      }

      setState(() {
        _allTickets = ticketsWithDetails;
        _isLoading = false;
        _applyFilter();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Helper method to determine ticket timing status based on showtime and movie duration
  TicketTimingStatus _getTicketTimingStatus(Showtime showtime, Movie movie) {
    final now = DateTime.now();
    final showtimeStart = showtime.showtime;
    final showtimeEnd = showtimeStart.add(
      Duration(minutes: movie.durationMinutes),
    );

    if (now.isBefore(showtimeStart)) {
      return TicketTimingStatus.upcoming;
    } else if (now.isAfter(showtimeStart) && now.isBefore(showtimeEnd)) {
      return TicketTimingStatus.active;
    } else {
      return TicketTimingStatus.past;
    }
  }

  void _applyFilter() {
    setState(() {
      switch (_currentFilter) {
        case TicketFilter.all:
          _filteredTickets = _allTickets;
          break;
        case TicketFilter.upcoming:
          _filteredTickets = _allTickets.where((item) {
            final showtime = item['showtime'] as Showtime;
            final movie = item['movie'] as Movie;
            return _getTicketTimingStatus(showtime, movie) ==
                TicketTimingStatus.upcoming;
          }).toList();
          break;
        case TicketFilter.active:
          _filteredTickets = _allTickets.where((item) {
            final showtime = item['showtime'] as Showtime;
            final movie = item['movie'] as Movie;
            return _getTicketTimingStatus(showtime, movie) ==
                TicketTimingStatus.active;
          }).toList();
          break;
        case TicketFilter.past:
          _filteredTickets = _allTickets.where((item) {
            final showtime = item['showtime'] as Showtime;
            final movie = item['movie'] as Movie;
            return _getTicketTimingStatus(showtime, movie) ==
                TicketTimingStatus.past;
          }).toList();
          break;
      }
    });
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
          'My Tickets',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildFilterChip('Upcoming', TicketFilter.upcoming),
                  const SizedBox(width: 8),
                  _buildFilterChip('Active', TicketFilter.active),
                  const SizedBox(width: 8),
                  _buildFilterChip('Past', TicketFilter.past),
                  const SizedBox(width: 8),
                  _buildFilterChip('All', TicketFilter.all),
                ],
              ),
            ),
          ),

          // Tickets List
          Expanded(
            child: _isLoading
                ? _buildLoadingSkeleton()
                : _error != null
                ? _buildErrorState()
                : _filteredTickets.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadTickets,
                    color: AppConstants.primaryColor,
                    backgroundColor: const Color(0xFF1F1F1F),
                    child: _buildTicketsList(),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNav(currentIndex: 1),
    );
  }

  Widget _buildFilterChip(String label, TicketFilter filter) {
    final isSelected = _currentFilter == filter;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentFilter = filter;
          _applyFilter();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppConstants.primaryColor
              : const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppConstants.primaryColor
                : const Color(0xFF2A2A2A),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF808080),
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) => const TicketCardSkeleton(),
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
            'Failed to load tickets',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _loadTickets,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    String subtitle;

    switch (_currentFilter) {
      case TicketFilter.upcoming:
        message = 'No Upcoming Shows';
        subtitle = 'Book tickets to watch movies';
        break;
      case TicketFilter.active:
        message = 'No Active Shows';
        subtitle = 'Your currently playing movies will appear here';
        break;
      case TicketFilter.past:
        message = 'No Past Shows';
        subtitle = 'Your watched movies will appear here';
        break;
      case TicketFilter.all:
        message = 'No Tickets Yet';
        subtitle = 'Start booking to see your tickets';
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.confirmation_number_outlined,
            size: 80,
            color: const Color(0xFF808080),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF808080), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketsList() {
    return RefreshIndicator(
      color: AppConstants.primaryColor,
      onRefresh: _loadTickets,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredTickets.length,
        itemBuilder: (context, index) {
          final item = _filteredTickets[index];
          final ticket = item['ticket'] as Ticket;
          final showtime = item['showtime'] as Showtime;
          final movie = item['movie'] as Movie;

          return _buildTicketCard(ticket, showtime, movie);
        },
      ),
    );
  }

  Widget _buildTicketCard(Ticket ticket, Showtime showtime, Movie movie) {
    final timingStatus = _getTicketTimingStatus(showtime, movie);
    final isPending = ticket.paymentStatus == PaymentStatus.pending;
    final isRejected = ticket.isRejected;
    final isExpired = timingStatus == TicketTimingStatus.past;

    // Determine status color based on payment, timing and ticket status
    final statusColor = isRejected
        ? Colors.red
        : isPending
        ? Colors.orange
        : isExpired
        ? Colors.red
        : ticket.isActive
        ? Colors.green
        : ticket.isUsed
        ? Colors.blue
        : Colors.red;

    // Determine status icon
    final statusIcon = isRejected
        ? Icons.cancel
        : isPending
        ? Icons.hourglass_top
        : isExpired
        ? Icons.cancel
        : ticket.isActive
        ? Icons.check_circle
        : ticket.isUsed
        ? Icons.movie
        : Icons.cancel;

    // Determine status text
    final statusText = isRejected
        ? 'REJECTED'
        : isPending
        ? 'PENDING APPROVAL'
        : isExpired
        ? 'EXPIRED'
        : ticket.status.name.toUpperCase();

    // Timing badge color
    final timingBadgeColor = timingStatus == TicketTimingStatus.upcoming
        ? Colors.blue
        : timingStatus == TicketTimingStatus.active
        ? Colors.green
        : const Color(0xFF808080);

    final timingBadgeText = timingStatus == TicketTimingStatus.upcoming
        ? 'UPCOMING'
        : timingStatus == TicketTimingStatus.active
        ? 'NOW PLAYING'
        : 'PAST';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TicketScreen(ticketId: ticket.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
        ),
        child: Column(
          children: [
            // Header with status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  if (!isPending && !isRejected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: timingBadgeColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        timingBadgeText,
                        style: TextStyle(
                          color: timingBadgeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Pending Banner
            if (isPending)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                color: Colors.orange.withOpacity(0.1),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Awaiting admin verification',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // Rejected Banner with reason
            if (isRejected)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                color: Colors.red.withOpacity(0.1),
                child: Row(
                  children: [
                    const Icon(Icons.cancel, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payment Rejected - Tap to resubmit',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (ticket.rejectionReason != null)
                            Text(
                              ticket.rejectionReason!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 11,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.red,
                      size: 20,
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
                          DateFormat(
                            'EEEE, MMM d, yyyy',
                          ).format(showtime.showtime),
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
                          '${ticket.seatIds.length} seat${ticket.seatIds.length == 1 ? '' : 's'}',
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              '₱${ticket.totalAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: AppConstants.primaryColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              isPending ? Icons.pending : Icons.qr_code,
                              color: statusColor,
                              size: 24,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // View Ticket Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isPending ? Icons.visibility : Icons.confirmation_number,
                    color: AppConstants.primaryColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isPending ? 'View Details' : 'View Ticket',
                    style: TextStyle(
                      color: AppConstants.primaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: AppConstants.primaryColor,
                    size: 12,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF808080), size: 14),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
