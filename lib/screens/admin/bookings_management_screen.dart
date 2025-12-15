import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/app_constants.dart';
import '../../services/supabase_service.dart';

class BookingsManagementScreen extends StatefulWidget {
  const BookingsManagementScreen({super.key});

  @override
  State<BookingsManagementScreen> createState() =>
      _BookingsManagementScreenState();
}

class _BookingsManagementScreenState extends State<BookingsManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _reservations = [];
  List<Map<String, dynamic>> _filteredTickets = [];
  List<Map<String, dynamic>> _filteredReservations = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterStatus = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _searchQuery = '';
          _filterStatus = 'All';
        });
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // First, clean up expired reservations and tickets
      await SupabaseService.runCleanupTasks();

      // Load tickets with related data
      final ticketsResponse = await SupabaseService.client
          .from('tickets')
          .select('''
            *,
            showtimes!inner (
              id,
              showtime,
              cinema_hall,
              movies (
                title,
                poster_url
              )
            )
          ''')
          .order('created_at', ascending: false);

      // Load reservations with related data
      final reservationsResponse = await SupabaseService.client
          .from('reservations')
          .select('''
            *,
            showtimes!inner (
              id,
              showtime,
              cinema_hall,
              movies (
                title,
                poster_url
              )
            )
          ''')
          .order('created_at', ascending: false);

      setState(() {
        _tickets = List<Map<String, dynamic>>.from(ticketsResponse);
        _reservations = List<Map<String, dynamic>>.from(reservationsResponse);
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      // Filter tickets
      _filteredTickets = _tickets.where((ticket) {
        final matchesSearch =
            _searchQuery.isEmpty ||
            ticket['ticket_number'].toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            ticket['payment_reference'].toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );

        final matchesStatus =
            _filterStatus == 'All' ||
            ticket['status'].toString().toLowerCase() ==
                _filterStatus.toLowerCase();

        return matchesSearch && matchesStatus;
      }).toList();

      // Filter reservations
      _filteredReservations = _reservations.where((reservation) {
        final matchesSearch =
            _searchQuery.isEmpty ||
            reservation['reservation_code'].toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );

        final matchesStatus =
            _filterStatus == 'All' ||
            reservation['status'].toString().toLowerCase() ==
                _filterStatus.toLowerCase();

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  Future<void> _showDetailsDialog(
    Map<String, dynamic> item,
    bool isTicket,
  ) async {
    final showtime = item['showtimes'];
    final movie = showtime['movies'];
    final showtimeDate = DateTime.parse(showtime['showtime']);
    final seats = List<String>.from(item['seat_ids'] ?? []);

    // Fetch seat details
    final seatDetails = await SupabaseService.client
        .from('seats')
        .select()
        .inFilter('id', seats);

    final seatLabels = seatDetails
        .map((seat) => '${seat['row_label']}${seat['seat_number']}')
        .join(', ');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(
          isTicket ? 'Ticket Details' : 'Reservation Details',
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Movie poster
              if (movie['poster_url'] != null)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      movie['poster_url'],
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              _buildDetailRow('Movie', movie['title']),
              _buildDetailRow(
                'Showtime',
                DateFormat('MMM dd, yyyy - hh:mm a').format(showtimeDate),
              ),
              _buildDetailRow('Cinema', showtime['cinema_hall']),
              _buildDetailRow('Seats', seatLabels),
              _buildDetailRow(
                'Amount',
                '₱${item['total_amount'].toStringAsFixed(2)}',
              ),
              if (isTicket) ...[
                _buildDetailRow('Ticket #', item['ticket_number']),
                _buildDetailRow('Payment Method', item['payment_method']),
                _buildDetailRow('Payment Ref', item['payment_reference']),
              ] else ...[
                _buildDetailRow('Reservation Code', item['reservation_code']),
                _buildDetailRow(
                  'Expires At',
                  DateFormat(
                    'MMM dd, yyyy - hh:mm a',
                  ).format(DateTime.parse(item['expires_at']).toLocal()),
                ),
              ],
              _buildDetailRow(
                'Status',
                item['status'].toString().toUpperCase(),
              ),
              _buildDetailRow(
                'Created',
                DateFormat(
                  'MMM dd, yyyy - hh:mm a',
                ).format(DateTime.parse(item['created_at'])),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
          if (!isTicket && item['status'] == 'pending')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _cancelReservation(item['id']);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Cancel Reservation'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelReservation(int reservationId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        title: const Text(
          'Cancel Reservation',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to cancel this reservation? The seats will be released.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Get reservation details
        final reservation = _reservations.firstWhere(
          (r) => r['id'] == reservationId,
        );
        final seatIds = List<int>.from(reservation['seat_ids']);

        // Release seats
        await SupabaseService.client
            .from('seats')
            .update({'status': 'available', 'user_id': null})
            .inFilter('id', seatIds);

        // Update reservation status
        await SupabaseService.client
            .from('reservations')
            .update({'status': 'cancelled'})
            .eq('id', reservationId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reservation cancelled successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error cancelling reservation: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Booking Management'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppConstants.primaryColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Tickets', icon: Icon(Icons.confirmation_number)),
            Tab(text: 'Reservations', icon: Icon(Icons.pending_actions)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: Column(
              children: [
                TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by reference number...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    _searchQuery = value;
                    _applyFilters();
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _filterStatus,
                  dropdownColor: AppColors.surface,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Status',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items:
                      [
                            'All',
                            'Active',
                            'Pending',
                            'Cancelled',
                            'Used',
                            'Confirmed',
                          ]
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    setState(() {
                      _filterStatus = value!;
                      _applyFilters();
                    });
                  },
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildTicketsList(), _buildReservationsList()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppConstants.primaryColor),
      );
    }

    if (_filteredTickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.confirmation_number_outlined,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'No tickets found',
              style: TextStyle(color: Colors.grey[400], fontSize: 18),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Stats
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_filteredTickets.length} tickets',
                style: TextStyle(color: Colors.grey[400]),
              ),
              Text(
                'Total: ₱${_filteredTickets.fold<double>(0, (sum, ticket) => sum + ticket['total_amount']).toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _filteredTickets.length,
            itemBuilder: (context, index) {
              final ticket = _filteredTickets[index];
              return _buildTicketCard(ticket);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReservationsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppConstants.primaryColor),
      );
    }

    if (_filteredReservations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pending_actions_outlined,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'No reservations found',
              style: TextStyle(color: Colors.grey[400], fontSize: 18),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Stats
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_filteredReservations.length} reservations',
                style: TextStyle(color: Colors.grey[400]),
              ),
              Text(
                'Pending: ${_filteredReservations.where((r) => r['status'] == 'pending').length}',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _filteredReservations.length,
            itemBuilder: (context, index) {
              final reservation = _filteredReservations[index];
              return _buildReservationCard(reservation);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final showtime = ticket['showtimes'];
    final movie = showtime['movies'];
    final showtimeDate = DateTime.parse(showtime['showtime']);
    final status = ticket['status'].toString();

    Color statusColor;
    switch (status.toLowerCase()) {
      case 'active':
        statusColor = Colors.green;
        break;
      case 'used':
        statusColor = Colors.blue;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showDetailsDialog(ticket, true),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Poster
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  movie['poster_url'] ?? '',
                  width: 60,
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 60,
                    height: 90,
                    color: Colors.grey[800],
                    child: const Icon(Icons.movie, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            movie['title'] ?? 'Untitled',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ticket['ticket_number'],
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM dd, yyyy - hh:mm a').format(showtimeDate),
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.meeting_room,
                          size: 14,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          showtime['cinema_hall'],
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.event_seat,
                          size: 14,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${(ticket['seat_ids'] as List).length} seats',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₱${ticket['total_amount'].toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReservationCard(Map<String, dynamic> reservation) {
    final showtime = reservation['showtimes'];
    final movie = showtime['movies'];
    final showtimeDate = DateTime.parse(showtime['showtime']);
    final expiresAt = DateTime.parse(reservation['expires_at']).toLocal();
    final status = reservation['status'].toString();
    final isExpired = DateTime.now().isAfter(expiresAt);

    Color statusColor;
    if (status == 'cancelled') {
      statusColor = Colors.red;
    } else if (isExpired) {
      statusColor = Colors.red;
    } else if (status == 'pending') {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.green;
    }

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showDetailsDialog(reservation, false),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Poster
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  movie['poster_url'] ?? '',
                  width: 60,
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 60,
                    height: 90,
                    color: Colors.grey[800],
                    child: const Icon(Icons.movie, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            movie['title'] ?? 'Untitled',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isExpired && status == 'pending'
                                ? 'EXPIRED'
                                : status.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reservation['reservation_code'],
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM dd, yyyy - hh:mm a').format(showtimeDate),
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    if (status == 'pending' && !isExpired)
                      Text(
                        'Expires: ${DateFormat('hh:mm a').format(expiresAt)}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.meeting_room,
                          size: 14,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          showtime['cinema_hall'],
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.event_seat,
                          size: 14,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${(reservation['seat_ids'] as List).length} seats',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₱${reservation['total_amount'].toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
