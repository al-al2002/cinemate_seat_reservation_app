import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/movie.dart';
import '../../services/supabase_service.dart';
import '../../constants/app_constants.dart';
import '../../widgets/movie_card.dart';
import '../../widgets/movie_filters.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/custom_bottom_nav.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Movie> _allMovies = [];
  List<Movie> _filteredMovies = [];
  bool _isLoading = true;
  String? _error;

  // Search and Filter state
  final TextEditingController _searchController = TextEditingController();
  List<String> _selectedGenres = [];
  List<String> _selectedLanguages = [];
  List<String> _selectedRatings = [];
  String _sortBy = 'latest'; // latest, oldest, title_az, title_za

  @override
  void initState() {
    super.initState();
    _loadMovies();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMovies() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Update movie statuses based on release dates
      await SupabaseService.client.rpc('update_movie_status');

      // Explicitly request only movie columns to avoid fetching related
      // relations (for example, user/profile) which can trigger
      // recursive RLS policy evaluation on some Supabase setups.
      final response = await SupabaseService.movies
          .select(
            'id,title,description,cast,genre,language,duration_minutes,release_date,trailer_url,poster_url,country,rating,is_active,created_at,updated_at,status',
          )
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final movies = (response as List)
          .map((json) => Movie.fromJson(json as Map<String, dynamic>))
          .toList();

      setState(() {
        _allMovies = movies;
        _filteredMovies = movies;
        _isLoading = false;
      });
    } catch (e) {
      // Detect common PostgREST/RLS recursion message and show friendlier hint.
      final msg = e.toString();
      if (msg.toLowerCase().contains('infinite recursion') ||
          msg.toLowerCase().contains('inifinite recursion') ||
          msg.toLowerCase().contains('recursion detected')) {
        setState(() {
          _error =
              'Failed to load movies from the server. This may be caused by a recursive Row-Level Security (RLS) policy on the backend. Please check your Supabase/Postgres RLS policies.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = msg;
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredMovies = _allMovies.where((movie) {
        // Search filter - search in title, description, and cast
        final searchQuery = _searchController.text.toLowerCase();
        final matchesSearch =
            searchQuery.isEmpty ||
            movie.title.toLowerCase().contains(searchQuery) ||
            (movie.description?.toLowerCase().contains(searchQuery) ?? false) ||
            movie.castMembers.any(
              (cast) => cast.toLowerCase().contains(searchQuery),
            );

        // Genre filter
        final matchesGenre =
            _selectedGenres.isEmpty ||
            movie.genre.any((g) => _selectedGenres.contains(g));

        // Language filter
        final matchesLanguage =
            _selectedLanguages.isEmpty ||
            _selectedLanguages.contains(movie.language);

        // MTRCB Rating filter
        final matchesRating =
            _selectedRatings.isEmpty ||
            (movie.rating != null && _selectedRatings.contains(movie.rating));

        return matchesSearch &&
            matchesGenre &&
            matchesLanguage &&
            matchesRating;
      }).toList();

      // Apply sorting
      _filteredMovies.sort((a, b) {
        switch (_sortBy) {
          case 'oldest':
            return a.createdAt.compareTo(b.createdAt);
          case 'title_az':
            return a.title.compareTo(b.title);
          case 'title_za':
            return b.title.compareTo(a.title);
          case 'latest':
          default:
            return b.createdAt.compareTo(a.createdAt);
        }
      });
    });
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedGenres.clear();
      _selectedLanguages.clear();
      _selectedRatings.clear();
      _sortBy = 'latest';
      _filteredMovies = _allMovies;
    });
    _applyFilters(); // Reapply to get proper sorting
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Row(
          children: [
            Icon(
              Icons.local_movies,
              color: AppConstants.primaryColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text(
              'Cinemate',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadMovies,
        color: AppConstants.primaryColor,
        backgroundColor: const Color(0xFF1F1F1F),
        child: _buildBody(),
      ),
      bottomNavigationBar: const CustomBottomNav(currentIndex: 0),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingSkeleton();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_allMovies.isEmpty) {
      return _buildEmptyState();
    }

    return _buildMovieGrid();
  }

  Widget _buildLoadingSkeleton() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2 / 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return const MovieCardSkeleton();
      },
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
            'Oops! Something went wrong',
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
            onPressed: _loadMovies,
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

  Widget _buildEmptyState() {
    final hasFilters =
        _searchController.text.isNotEmpty ||
        _selectedGenres.isNotEmpty ||
        _selectedLanguages.isNotEmpty ||
        _selectedRatings.isNotEmpty;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilters ? Icons.search_off : Icons.movie_outlined,
            size: 100,
            color: AppConstants.primaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            hasFilters ? 'No Movies Found' : 'No Movies Available',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hasFilters
                ? 'Try adjusting your filters'
                : 'Check back soon for new releases!',
            style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 16),
          ),
          const SizedBox(height: 32),
          if (hasFilters)
            ElevatedButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Filters'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _loadMovies,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMovieGrid() {
    // Separate movies by status
    final nowShowingMovies = _filteredMovies
        .where((m) => m.status == 'now_showing')
        .toList();
    final upcomingMovies = _filteredMovies
        .where((m) => m.status == 'upcoming')
        .toList();

    // Handle movies with null status (fallback: treat as now showing if release date passed)
    final moviesWithoutStatus = _filteredMovies
        .where(
          (m) =>
              m.status == null ||
              (m.status != 'now_showing' && m.status != 'upcoming'),
        )
        .toList();

    for (final movie in moviesWithoutStatus) {
      final today = DateTime.now();
      final releaseDate = DateTime(
        movie.releaseDate.year,
        movie.releaseDate.month,
        movie.releaseDate.day,
      );
      final currentDate = DateTime(today.year, today.month, today.day);

      if (releaseDate.isAfter(currentDate)) {
        upcomingMovies.add(movie);
      } else {
        nowShowingMovies.add(movie);
      }
    }

    // If no movies in either section after filtering, show empty state
    if (nowShowingMovies.isEmpty && upcomingMovies.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by title, description, or cast...',
                hintStyle: const TextStyle(color: Color(0xFF808080)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF808080)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF808080)),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppConstants.primaryColor,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Filters
            MovieFilters(
              selectedGenres: _selectedGenres,
              selectedLanguages: _selectedLanguages,
              selectedRatings: _selectedRatings,
              onGenresChanged: (genres) {
                setState(() => _selectedGenres = genres);
                _applyFilters();
              },
              onLanguagesChanged: (languages) {
                setState(() => _selectedLanguages = languages);
                _applyFilters();
              },
              onRatingsChanged: (ratings) {
                setState(() => _selectedRatings = ratings);
                _applyFilters();
              },
              onClearAll: _clearFilters,
            ),
            const SizedBox(height: 48),

            // No results message
            Center(
              child: Padding(
                padding: const EdgeInsets.all(48.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 80,
                      color: AppConstants.primaryColor.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No movies match your filters',
                      style: TextStyle(color: Color(0xFFB3B3B3), fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      // Add extra bottom padding so content isn't hidden under the BottomNavigationBar
      // and to avoid RenderFlex overflow when the viewport is constrained.
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by title, description, or cast...',
              hintStyle: const TextStyle(color: Color(0xFF808080)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF808080)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Color(0xFF808080)),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF2A2A2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: AppConstants.primaryColor,
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Filters
          MovieFilters(
            selectedGenres: _selectedGenres,
            selectedLanguages: _selectedLanguages,
            selectedRatings: _selectedRatings,
            onGenresChanged: (genres) {
              setState(() => _selectedGenres = genres);
              _applyFilters();
            },
            onLanguagesChanged: (languages) {
              setState(() => _selectedLanguages = languages);
              _applyFilters();
            },
            onRatingsChanged: (ratings) {
              setState(() => _selectedRatings = ratings);
              _applyFilters();
            },
            onClearAll: _clearFilters,
          ),
          const SizedBox(height: 24),

          // Now Showing Section
          if (nowShowingMovies.isNotEmpty) ...[
            _buildSectionHeader(
              'Now Showing',
              nowShowingMovies.length,
              () => _showAllMovies('Now Showing', nowShowingMovies),
            ),
            const SizedBox(height: 16),
            _buildHorizontalMovieList(nowShowingMovies),
            const SizedBox(height: 32),
          ],

          // Upcoming Section
          if (upcomingMovies.isNotEmpty) ...[
            _buildSectionHeader(
              'Coming Soon',
              upcomingMovies.length,
              () => _showAllMovies('Coming Soon', upcomingMovies),
            ),
            const SizedBox(height: 16),
            _buildHorizontalMovieList(upcomingMovies),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, VoidCallback onSeeAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // See All Button
        TextButton(
          onPressed: onSeeAll,
          style: TextButton.styleFrom(
            foregroundColor: AppConstants.primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: const Row(
            children: [
              Text(
                'See All',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward, size: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalMovieList(List<Movie> movies) {
    return SizedBox(
      height: 280,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: movies.length > 10 ? 10 : movies.length,
        itemBuilder: (context, index) {
          return Container(
            width: 160,
            margin: EdgeInsets.only(left: index == 0 ? 0 : 0, right: 12),
            child: MovieCard(
              movie: movies[index],
              onTap: () {
                context.push('/movie/${movies[index].id}');
              },
            ),
          );
        },
      ),
    );
  }

  void _showAllMovies(String title, List<Movie> movies) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _AllMoviesScreen(
          title: title,
          movies: movies,
          sortBy: _sortBy,
          onSortChanged: (newSort) {
            setState(() => _sortBy = newSort);
            _applyFilters();
          },
        ),
      ),
    );
  }
}

class _AllMoviesScreen extends StatelessWidget {
  final String title;
  final List<Movie> movies;
  final String sortBy;
  final Function(String) onSortChanged;

  const _AllMoviesScreen({
    required this.title,
    required this.movies,
    required this.sortBy,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Icon(
              Icons.local_movies,
              color: AppConstants.primaryColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: DropdownButton<String>(
              value: sortBy,
              icon: const Icon(Icons.sort, color: Colors.white, size: 20),
              dropdownColor: const Color(0xFF2A2A2A),
              underline: const SizedBox(),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: const [
                DropdownMenuItem(value: 'latest', child: Text('Latest First')),
                DropdownMenuItem(value: 'oldest', child: Text('Oldest First')),
                DropdownMenuItem(value: 'title_az', child: Text('Title: A-Z')),
                DropdownMenuItem(value: 'title_za', child: Text('Title: Z-A')),
              ],
              onChanged: (value) {
                if (value != null) {
                  onSortChanged(value);
                }
              },
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = 2;
          if (constraints.maxWidth > 1200) {
            crossAxisCount = 4;
          } else if (constraints.maxWidth > 800) {
            crossAxisCount = 3;
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 2 / 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              return MovieCard(
                movie: movies[index],
                onTap: () {
                  context.push('/movie/${movies[index].id}');
                },
              );
            },
          );
        },
      ),
    );
  }
}
