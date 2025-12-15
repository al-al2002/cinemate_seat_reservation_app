import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../constants/app_constants.dart';
import 'movies_management_screen.dart';
import 'showtimes_management_screen.dart';
import 'bookings_management_screen.dart';
import 'users_management_screen.dart';
import 'admin_pending_payments_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  String? _error;

  // Statistics
  int _totalMovies = 0;
  int _activeMovies = 0;
  int _totalShowtimes = 0;
  int _totalBookings = 0;
  int _totalReservations = 0;
  int _pendingPayments = 0;
  double _totalRevenue = 0;
  int _todayBookings = 0;
  double _todayRevenue = 0;

  // Popular movies data
  List<Map<String, dynamic>> _popularMovies = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load movies statistics
      final moviesResponse = await SupabaseService.movies.select();
      _totalMovies = (moviesResponse as List).length;
      _activeMovies = moviesResponse
          .where((m) => m['is_active'] == true)
          .length;

      // Load showtimes count
      final showtimesResponse = await SupabaseService.showtimes.select();
      _totalShowtimes = (showtimesResponse as List).length;

      // Load tickets/bookings
      final ticketsResponse = await SupabaseService.tickets.select();
      final tickets = ticketsResponse as List;
      _totalBookings = tickets.length;

      // Calculate revenue
      _totalRevenue = tickets.fold<double>(
        0,
        (sum, ticket) => sum + (ticket['total_amount'] as num).toDouble(),
      );

      // Today's bookings and revenue
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayTickets = tickets.where((ticket) {
        final createdAt = DateTime.parse(ticket['created_at']);
        return createdAt.isAfter(todayStart);
      }).toList();

      _todayBookings = todayTickets.length;
      _todayRevenue = todayTickets.fold<double>(
        0,
        (sum, ticket) => sum + (ticket['total_amount'] as num).toDouble(),
      );

      // Load reservations count
      final reservationsResponse = await SupabaseService.reservations
          .select()
          .eq('status', 'pending');
      _totalReservations = (reservationsResponse as List).length;

      // Load pending payments count (by payment_status, not status)
      final pendingPaymentsResponse = await SupabaseService.tickets.select().eq(
        'payment_status',
        'pending',
      );
      _pendingPayments = (pendingPaymentsResponse as List).length;

      // Load popular movies (by booking count)
      final movieBookings = <String, int>{};
      for (var ticket in tickets) {
        // Get showtime to find movie
        final showtimeId = ticket['showtime_id'];
        try {
          final showtime = showtimesResponse.firstWhere(
            (s) => s['id'] == showtimeId,
          );

          final movieId = showtime['movie_id'];
          movieBookings[movieId] = (movieBookings[movieId] ?? 0) + 1;
        } catch (e) {
          // Showtime not found, skip
          continue;
        }
      }

      // Get top 5 movies
      final sortedMovies = movieBookings.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      _popularMovies = [];
      for (var entry in sortedMovies.take(5)) {
        try {
          final movie = moviesResponse.firstWhere((m) => m['id'] == entry.key);

          _popularMovies.add({
            'title': movie['title'],
            'bookings': entry.value,
            'poster_url': movie['poster_url'],
          });
        } catch (e) {
          // Movie not found, skip
          continue;
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Icon(
              Icons.admin_panel_settings,
              color: AppConstants.primaryColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text(
              'Admin Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppConstants.primaryColor,
              ),
            )
          : _error != null
          ? _buildErrorState()
          : _buildDashboardContent(),
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
            'Failed to load dashboard',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _loadDashboardData,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    return RefreshIndicator(
      color: AppConstants.primaryColor,
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Today's Stats
            const Text(
              "Today's Performance",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Today\'s Bookings',
                    _todayBookings.toString(),
                    Icons.today,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Today\'s Revenue',
                    '₱${_todayRevenue.toStringAsFixed(0)}',
                    Icons.attach_money,
                    Colors.green,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Overall Statistics
            const Text(
              'Overall Statistics',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            _buildStatCard(
              'Total Revenue',
              '₱${_totalRevenue.toStringAsFixed(2)}',
              Icons.currency_exchange,
              AppConstants.primaryColor,
              isLarge: true,
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Bookings',
                    _totalBookings.toString(),
                    Icons.confirmation_number,
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Pending Payments',
                    _pendingPayments.toString(),
                    Icons.pending_actions,
                    Colors.amber,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Pending Reservations',
                    _totalReservations.toString(),
                    Icons.event_seat,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Total Movies',
                    _totalMovies.toString(),
                    Icons.movie,
                    Colors.pink,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Active Movies',
                    _activeMovies.toString(),
                    Icons.play_circle,
                    Colors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Total Showtimes',
                    _totalShowtimes.toString(),
                    Icons.schedule,
                    Colors.indigo,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Popular Movies
            const Text(
              'Top 5 Popular Movies',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            if (_popularMovies.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1F1F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'No bookings yet',
                    style: TextStyle(color: Color(0xFF808080), fontSize: 14),
                  ),
                ),
              )
            else
              ..._popularMovies.map((movie) => _buildPopularMovieCard(movie)),

            const SizedBox(height: 32),

            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            _buildActionButton(
              'Manage Movies',
              'Add, edit, or remove movies',
              Icons.movie_creation,
              Colors.purple,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MoviesManagementScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              'Manage Showtimes',
              'Schedule and manage showtimes',
              Icons.event,
              Colors.blue,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ShowtimesManagementScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              'View All Bookings',
              'Manage bookings and reservations',
              Icons.list_alt,
              Colors.green,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BookingsManagementScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              'Pending Payments',
              'Approve GCash/Maya payments',
              Icons.pending_actions,
              Colors.amber,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminPendingPaymentsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              'Manage Users',
              'View and manage user accounts',
              Icons.people,
              Colors.orange,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UsersManagementScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool isLarge = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isLarge ? 24 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: isLarge ? 28 : 20),
              ),
              const Spacer(),
            ],
          ),
          SizedBox(height: isLarge ? 16 : 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: isLarge ? 32 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF808080), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularMovieCard(Map<String, dynamic> movie) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Ranking
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '#${_popularMovies.indexOf(movie) + 1}',
                style: TextStyle(
                  color: AppConstants.primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Movie Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie['title'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${movie['bookings']} booking${movie['bookings'] == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Color(0xFF808080),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Bookings Count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              movie['bookings'].toString(),
              style: const TextStyle(
                color: Colors.green,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF808080),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
