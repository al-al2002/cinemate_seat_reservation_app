import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../models/movie.dart';
import '../../models/showtime.dart';
import '../../services/supabase_service.dart';
import '../../constants/app_constants.dart';
import 'package:intl/intl.dart';
import '../../widgets/movie_reviews_section.dart';

class MovieDetailsScreen extends StatefulWidget {
  final String movieId;

  const MovieDetailsScreen({super.key, required this.movieId});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  Movie? _movie;
  List<Showtime> _showtimes = [];
  List<Showtime> _filteredShowtimes = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedShowtimeId;
  String? _selectedCinemaHall;

  @override
  void initState() {
    super.initState();
    _loadMovieDetails();
  }

  Future<void> _loadMovieDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load movie details
      final movieResponse = await SupabaseService.movies
          .select()
          .eq('id', widget.movieId)
          .single();

      // Load showtimes for this movie (including past ones to show all cinema halls)
      final showtimesResponse = await SupabaseService.showtimes
          .select()
          .eq('movie_id', widget.movieId)
          .order('showtime', ascending: true);

      final allShowtimes = (showtimesResponse as List)
          .map((json) => Showtime.fromJson(json))
          .toList();

      final movie = Movie.fromJson(movieResponse);

      // Keep all showtimes for today and future dates
      // (UI will disable ones that have already started)
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final showtimes = allShowtimes.where((showtime) {
        final showtimeDate = DateTime(
          showtime.showtime.year,
          showtime.showtime.month,
          showtime.showtime.day,
        );
        // Keep showtimes for today or future dates
        return showtimeDate.isAtSameMomentAs(today) ||
            showtimeDate.isAfter(today);
      }).toList();

      final availableHalls = showtimes.map((s) => s.cinemaHall).toSet().toList()
        ..sort();

      setState(() {
        _movie = movie;
        _showtimes = showtimes;
        // Auto-select first cinema hall if showtimes exist
        if (availableHalls.isNotEmpty) {
          _selectedCinemaHall = availableHalls.first;
          _filteredShowtimes = showtimes
              .where((s) => s.cinemaHall == _selectedCinemaHall)
              .toList();
        } else {
          _filteredShowtimes = [];
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _playTrailer() async {
    if (_movie?.trailerUrl == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No trailer available'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final url = Uri.parse(_movie!.trailerUrl!);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open trailer'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterByCinemaHall(String hall) {
    setState(() {
      _selectedCinemaHall = hall;
      _selectedShowtimeId = null; // Reset showtime selection

      _filteredShowtimes = _showtimes
          .where((showtime) => showtime.cinemaHall == hall)
          .toList();
    });
  }

  List<String> _getAvailableCinemaHalls() {
    final halls = _showtimes.map((s) => s.cinemaHall).toSet().toList();
    halls.sort();
    return halls;
  }

  void _bookShowtime() {
    if (_selectedShowtimeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a showtime'),
          backgroundColor: AppConstants.primaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Check if selected showtime has already started
    final selectedShowtime = _showtimes.firstWhere(
      (s) => s.id == _selectedShowtimeId,
      orElse: () => _showtimes.first,
    );

    final now = DateTime.now();
    if (selectedShowtime.showtime.isBefore(now) ||
        selectedShowtime.showtime.isAtSameMomentAs(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Cannot book a showtime that has already started',
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Navigate to seat selection
    context.push('/seats/$_selectedShowtimeId');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
          ? _buildErrorState()
          : _movie == null
          ? _buildNotFoundState()
          : Stack(
              children: [
                _buildMovieDetails(),
                // Bottom Book Button
                if (_showtimes.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black,
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
                        child: ElevatedButton(
                          onPressed: _bookShowtime,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Book Seats',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
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
            'Failed to load movie',
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
            onPressed: _loadMovieDetails,
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

  Widget _buildNotFoundState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.movie_outlined,
            size: 80,
            color: AppConstants.primaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          const Text(
            'Movie Not Found',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Go Back'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovieDetails() {
    return CustomScrollView(
      slivers: [
        // App Bar with Poster Background
        SliverAppBar(
          expandedHeight: 400,
          pinned: true,
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                // Poster Image
                CachedNetworkImage(
                  imageUrl: _movie!.posterUrl ?? '',
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: const Color(0xFF2A2A2A),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppConstants.primaryColor,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: const Color(0xFF2A2A2A),
                    child: const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                ),
                // Gradient Overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                        Colors.black,
                      ],
                      stops: const [0.0, 0.7, 1.0],
                    ),
                  ),
                ),
                // Play Trailer Button
                if (_movie!.trailerUrl != null)
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: ElevatedButton.icon(
                      onPressed: _playTrailer,
                      icon: const Icon(Icons.play_arrow, size: 28),
                      label: const Text(
                        'Watch Trailer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Movie Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  _movie!.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Metadata Row
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    if (_movie!.rating != null)
                      _buildMetadataChip(
                        Icons.star,
                        _movie!.rating!,
                        AppConstants.primaryColor,
                      ),
                    _buildMetadataChip(
                      Icons.language,
                      _movie!.language,
                      Colors.blue,
                    ),
                    _buildMetadataChip(
                      Icons.access_time,
                      _movie!.durationFormatted,
                      Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Genres
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _movie!.genre.map((genre) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppConstants.primaryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        genre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Description
                const Text(
                  'Synopsis',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _movie!.description ?? 'No description available',
                  style: const TextStyle(
                    color: Color(0xFFB3B3B3),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),

                // Cast
                if (_movie!.castMembers.isNotEmpty) ...[
                  const Text(
                    'Cast',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _movie!.castMembers.join(', '),
                    style: const TextStyle(
                      color: Color(0xFFB3B3B3),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Reviews Section
                const Divider(color: Color(0xFF2A2A2A), thickness: 2),
                const SizedBox(height: 24),
                MovieReviewsSection(movieId: widget.movieId),
                const SizedBox(height: 24),

                // Showtimes Section
                const Divider(color: Color(0xFF2A2A2A), thickness: 2),
                const SizedBox(height: 24),
                const Text(
                  'Select Showtime',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Cinema Hall Filter Buttons
                if (_showtimes.isNotEmpty) ...[
                  const Text(
                    'Cinema Hall',
                    style: TextStyle(
                      color: Color(0xFFB3B3B3),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _getAvailableCinemaHalls()
                        .map((hall) => _buildCinemaHallButton(hall, hall))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                if (_showtimes.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F1F1F),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'No upcoming showtimes available for this movie.',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  _buildShowtimesList(),

                const SizedBox(height: 100), // Space for bottom button
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShowtimesList() {
    // Clear selection if selected showtime has started
    if (_selectedShowtimeId != null) {
      final selectedShowtime = _filteredShowtimes
          .where((s) => s.id == _selectedShowtimeId)
          .firstOrNull;
      if (selectedShowtime != null) {
        final now = DateTime.now();
        if (selectedShowtime.showtime.isBefore(now) ||
            selectedShowtime.showtime.isAtSameMomentAs(now)) {
          // Clear the selection in the next frame to avoid setState during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _selectedShowtimeId = null;
              });
            }
          });
        }
      }
    }

    // Group showtimes by date
    final Map<String, List<Showtime>> showtimesByDate = {};
    for (var showtime in _filteredShowtimes) {
      final dateKey = DateFormat(
        'EEEE, MMMM d, yyyy',
      ).format(showtime.showtime);
      if (!showtimesByDate.containsKey(dateKey)) {
        showtimesByDate[dateKey] = [];
      }
      showtimesByDate[dateKey]!.add(showtime);
    }

    if (showtimesByDate.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _selectedCinemaHall == null
                    ? 'No upcoming showtimes available.'
                    : 'No showtimes available for $_selectedCinemaHall.',
                style: const TextStyle(color: Colors.orange, fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: showtimesByDate.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                entry.key,
                style: TextStyle(
                  color: AppConstants.primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: entry.value.map((showtime) {
                // Check if showtime has started or passed
                final now = DateTime.now();
                final isPast =
                    now.isAfter(showtime.showtime) ||
                    now.isAtSameMomentAs(showtime.showtime);

                // Debug output
                print(
                  'Now: $now, Showtime: ${showtime.showtime}, isPast: $isPast',
                );

                final isSelected =
                    !isPast && _selectedShowtimeId == showtime.id;
                final timeStr = DateFormat('h:mm a').format(showtime.showtime);

                return Opacity(
                  opacity: isPast ? 0.5 : 1.0,
                  child: InkWell(
                    onTap: isPast
                        ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'You can\'t book this time because the movie has already started',
                                ),
                                backgroundColor: Colors.orange,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        : () {
                            setState(() {
                              _selectedShowtimeId = showtime.id;
                            });
                          },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: isPast ? 8 : 12,
                      ),
                      decoration: BoxDecoration(
                        color: isPast
                            ? const Color(0xFF1A1A1A)
                            : isSelected
                            ? AppConstants.primaryColor
                            : const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isPast
                              ? const Color(0xFF303030)
                              : isSelected
                              ? AppConstants.primaryColor
                              : const Color(0xFF404040),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isPast)
                                const Icon(
                                  Icons.access_time,
                                  color: Color(0xFF666666),
                                  size: 14,
                                ),
                              if (isPast) const SizedBox(width: 4),
                              Text(
                                timeStr,
                                style: TextStyle(
                                  color: isPast
                                      ? const Color(0xFF666666)
                                      : Colors.white,
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          if (isPast) ...[
                            const SizedBox(height: 2),
                            const Text(
                              'Started',
                              style: TextStyle(
                                color: Color(0xFF888888),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildCinemaHallButton(String label, String hallValue) {
    final isSelected = _selectedCinemaHall == hallValue;

    return InkWell(
      onTap: () => _filterByCinemaHall(hallValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppConstants.primaryColor
              : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppConstants.primaryColor
                : const Color(0xFF404040),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.theater_comedy, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
