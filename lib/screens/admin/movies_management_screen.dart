import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../../constants/app_constants.dart';
import '../../services/supabase_service.dart';

class MoviesManagementScreen extends StatefulWidget {
  const MoviesManagementScreen({super.key});

  @override
  State<MoviesManagementScreen> createState() => _MoviesManagementScreenState();
}

class _MoviesManagementScreenState extends State<MoviesManagementScreen> {
  List<Map<String, dynamic>> _movies = [];
  List<Map<String, dynamic>> _filteredMovies = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterGenre = 'All';
  String _filterStatus = 'All';

  final List<String> _genres = [
    'All',
    'Action',
    'Comedy',
    'Drama',
    'Horror',
    'Romance',
    'Sci-Fi',
    'Thriller',
  ];

  @override
  void initState() {
    super.initState();
    _loadMovies();
  }

  Future<void> _loadMovies() async {
    setState(() => _isLoading = true);
    try {
      final response = await SupabaseService.client
          .from('movies')
          .select()
          .order('created_at', ascending: false);

      setState(() {
        _movies = List<Map<String, dynamic>>.from(response);
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading movies: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredMovies = _movies.where((movie) {
        // Search filter
        final matchesSearch =
            _searchQuery.isEmpty ||
            movie['title'].toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );

        // Genre filter
        final matchesGenre =
            _filterGenre == 'All' || movie['genre'] == _filterGenre;

        // Status filter
        final matchesStatus =
            _filterStatus == 'All' ||
            (_filterStatus == 'Active' && movie['is_active'] == true) ||
            (_filterStatus == 'Inactive' && movie['is_active'] == false);

        return matchesSearch && matchesGenre && matchesStatus;
      }).toList();
    });
  }

  void _showAddEditDialog({Map<String, dynamic>? movie}) {
    final isEdit = movie != null;
    final titleController = TextEditingController(text: movie?['title'] ?? '');
    final descriptionController = TextEditingController(
      text: movie?['description'] ?? '',
    );
    final durationController = TextEditingController(
      text: movie?['duration']?.toString() ?? '',
    );
    final ratingController = TextEditingController(
      text: movie?['rating']?.toString() ?? '',
    );
    final trailerUrlController = TextEditingController(
      text: movie?['trailer_url'] ?? '',
    );
    final castController = TextEditingController(text: movie?['cast'] ?? '');
    final releaseDateController = TextEditingController(
      text: movie?['release_date'] ?? DateTime.now().toString().split(' ')[0],
    );

    String selectedGenre = movie?['genre'] ?? 'Action';
    String selectedLanguage = movie?['language'] ?? 'English';
    bool isActive = movie?['is_active'] ?? true;

    // Image upload state
    Uint8List? selectedImageBytes;
    String? selectedImageName;
    String? existingPosterUrl = movie?['poster_url'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.background,
          title: Text(
            isEdit ? 'Edit Movie' : 'Add New Movie',
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Title *',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(
                          color: AppConstants.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description *',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(
                          color: AppConstants.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedGenre,
                          dropdownColor: AppColors.surface,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Genre *',
                            labelStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AppConstants.primaryColor,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                          ),
                          isExpanded: true,
                          items: _genres
                              .where((g) => g != 'All')
                              .map(
                                (genre) => DropdownMenuItem(
                                  value: genre,
                                  child: Text(
                                    genre,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setDialogState(() => selectedGenre = value!);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedLanguage,
                          dropdownColor: AppColors.surface,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Language *',
                            labelStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AppConstants.primaryColor,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                          ),
                          isExpanded: true,
                          items: ['English', 'Filipino', 'Korean', 'Japanese']
                              .map(
                                (lang) => DropdownMenuItem(
                                  value: lang,
                                  child: Text(
                                    lang,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setDialogState(() => selectedLanguage = value!);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: durationController,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Duration (min) *',
                            labelStyle: TextStyle(color: Colors.grey[400]),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AppConstants.primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: ratingController,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Rating (1-10) *',
                            labelStyle: TextStyle(color: Colors.grey[400]),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AppConstants.primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Poster Image Upload
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Movie Poster *',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[700]!),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[900],
                        ),
                        child: selectedImageBytes != null
                            ? Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      selectedImageBytes!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                      ),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.black54,
                                      ),
                                      onPressed: () {
                                        setDialogState(() {
                                          selectedImageBytes = null;
                                          selectedImageName = null;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              )
                            : existingPosterUrl != null &&
                                  existingPosterUrl.isNotEmpty
                            ? Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      existingPosterUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      errorBuilder: (context, error, stack) =>
                                          const Center(
                                            child: Icon(
                                              Icons.error,
                                              color: Colors.grey,
                                            ),
                                          ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.upload, size: 18),
                                      label: const Text('Change'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppConstants.primaryColor,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () async {
                                        final result = await FilePicker.platform
                                            .pickFiles(
                                              type: FileType.image,
                                              withData: true,
                                            );
                                        if (result != null) {
                                          setDialogState(() {
                                            selectedImageBytes =
                                                result.files.first.bytes;
                                            selectedImageName =
                                                result.files.first.name;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              )
                            : Center(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.upload),
                                  label: const Text('Upload Poster Image'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppConstants.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    ),
                                  ),
                                  onPressed: () async {
                                    final result = await FilePicker.platform
                                        .pickFiles(
                                          type: FileType.image,
                                          withData: true,
                                        );
                                    if (result != null) {
                                      setDialogState(() {
                                        selectedImageBytes =
                                            result.files.first.bytes;
                                        selectedImageName =
                                            result.files.first.name;
                                      });
                                    }
                                  },
                                ),
                              ),
                      ),
                      if (selectedImageName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Selected: $selectedImageName',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: trailerUrlController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Trailer URL',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(
                          color: AppConstants.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: castController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Cast (comma-separated)',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(
                          color: AppConstants.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: releaseDateController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Release Date (YYYY-MM-DD) *',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      hintText: '2025-01-01',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(
                          color: AppConstants.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text(
                      'Active',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Show this movie to users',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    value: isActive,
                    activeColor: Colors.green,
                    onChanged: (value) {
                      setDialogState(() => isActive = value);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => _saveMovie(
                movie?['id'],
                titleController.text,
                descriptionController.text,
                selectedGenre,
                selectedLanguage,
                durationController.text,
                ratingController.text,
                selectedImageBytes,
                selectedImageName,
                existingPosterUrl,
                trailerUrlController.text,
                castController.text,
                releaseDateController.text,
                isActive,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
              ),
              child: Text(isEdit ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveMovie(
    String? id,
    String title,
    String description,
    String genre,
    String language,
    String duration,
    String rating,
    Uint8List? imageBytes,
    String? imageName,
    String? existingPosterUrl,
    String trailerUrl,
    String cast,
    String releaseDate,
    bool isActive,
  ) async {
    // Validation
    if (title.isEmpty ||
        description.isEmpty ||
        duration.isEmpty ||
        rating.isEmpty ||
        (imageBytes == null &&
            (existingPosterUrl == null || existingPosterUrl.isEmpty)) ||
        releaseDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields and upload a poster'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final durationInt = int.tryParse(duration);
    final ratingDouble = double.tryParse(rating);

    if (durationInt == null || ratingDouble == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid duration or rating'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (ratingDouble < 1 || ratingDouble > 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rating must be between 1 and 10'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Upload poster image if new image is selected
      String finalPosterUrl = existingPosterUrl ?? '';

      if (imageBytes != null && imageName != null) {
        // Show uploading message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uploading poster image...'),
              backgroundColor: AppConstants.primaryColor,
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Upload to Supabase Storage
        finalPosterUrl = await SupabaseService.uploadMoviePoster(
          imageName,
          imageBytes,
        );
      }

      // Determine movie status based on release date
      final releaseDateObj = DateTime.parse(releaseDate);
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final movieReleaseDate = DateTime(
        releaseDateObj.year,
        releaseDateObj.month,
        releaseDateObj.day,
      );

      String movieStatus;
      if (movieReleaseDate.isAfter(todayDate)) {
        movieStatus = 'upcoming';
      } else if (movieReleaseDate.isAtSameMomentAs(todayDate) ||
          movieReleaseDate.isBefore(todayDate)) {
        movieStatus = 'now_showing';
      } else {
        movieStatus = 'upcoming';
      }

      final movieData = {
        'title': title,
        'description': description,
        'genre': [genre], // Convert to array for database
        'language': language,
        'duration_minutes':
            durationInt, // Fixed: column name is duration_minutes
        'rating': ratingDouble,
        'poster_url': finalPosterUrl,
        'trailer_url': trailerUrl.isEmpty ? null : trailerUrl,
        'cast': cast.isEmpty ? null : cast,
        'release_date': releaseDate,
        'is_active': isActive,
        'status': movieStatus, // Auto-set status based on release date
      };

      if (id == null) {
        // Add new movie
        await SupabaseService.client.from('movies').insert(movieData);
      } else {
        // Update existing movie
        await SupabaseService.client
            .from('movies')
            .update(movieData)
            .eq('id', id);
      }

      // Call database function to update movie statuses
      await SupabaseService.client.rpc('update_movie_status');

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              id == null
                  ? 'Movie added successfully!'
                  : 'Movie updated successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadMovies();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving movie: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteMovie(String id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        title: const Text(
          'Delete Movie',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "$title"?\n\nThis will also delete all related showtimes, seats, reservations, tickets, and reviews. This action cannot be undone.',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Show deleting message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Deleting movie and related data...'),
              backgroundColor: AppConstants.primaryColor,
              duration: Duration(seconds: 3),
            ),
          );
        }

        // Delete in reverse order of dependencies

        // 1. Get all showtimes for this movie
        final showtimesResponse = await SupabaseService.client
            .from('showtimes')
            .select('id')
            .eq('movie_id', id);

        final showtimeIds = (showtimesResponse as List)
            .map((s) => s['id'] as String)
            .toList();

        // 2. Delete tickets for these showtimes
        if (showtimeIds.isNotEmpty) {
          for (var showtimeId in showtimeIds) {
            await SupabaseService.client
                .from('tickets')
                .delete()
                .eq('showtime_id', showtimeId);
          }

          // 3. Delete reservations for these showtimes
          for (var showtimeId in showtimeIds) {
            await SupabaseService.client
                .from('reservations')
                .delete()
                .eq('showtime_id', showtimeId);
          }

          // 4. Delete seats for these showtimes
          for (var showtimeId in showtimeIds) {
            await SupabaseService.client
                .from('seats')
                .delete()
                .eq('showtime_id', showtimeId);
          }
        }

        // 5. Delete showtimes
        await SupabaseService.client
            .from('showtimes')
            .delete()
            .eq('movie_id', id);

        // 6. Delete reviews
        await SupabaseService.client
            .from('reviews')
            .delete()
            .eq('movie_id', id);

        // 7. Finally delete the movie
        await SupabaseService.client.from('movies').delete().eq('id', id);

        if (mounted) {
          Navigator.pop(context); // Close any open dialogs
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Movie and all related data deleted successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          await _loadMovies();
        }
      } catch (e) {
        print('Delete error: $e'); // Debug print
        if (mounted) {
          Navigator.pop(context); // Close any open dialogs
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting movie: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleActive(String id, bool currentStatus) async {
    try {
      await SupabaseService.client
          .from('movies')
          .update({'is_active': !currentStatus})
          .eq('id', id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentStatus ? 'Movie deactivated' : 'Movie activated',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadMovies();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Movie Management'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMovies),
        ],
      ),
      body: Column(
        children: [
          // Search and Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: Column(
              children: [
                TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search movies...',
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
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterGenre,
                        dropdownColor: AppColors.surface,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Genre',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: _genres
                            .map(
                              (genre) => DropdownMenuItem(
                                value: genre,
                                child: Text(genre),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _filterGenre = value!;
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
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
                        items: ['All', 'Active', 'Inactive']
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
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Results count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredMovies.length} movies found',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                Text(
                  'Total: ${_movies.length}',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
          ),

          // Movies List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppConstants.primaryColor,
                    ),
                  )
                : _filteredMovies.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.movie_outlined,
                          size: 64,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No movies found',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredMovies.length,
                    itemBuilder: (context, index) {
                      final movie = _filteredMovies[index];
                      return _buildMovieCard(movie);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppConstants.primaryColor,
        icon: const Icon(Icons.add),
        label: const Text('Add Movie'),
      ),
    );
  }

  Widget _buildMovieCard(Map<String, dynamic> movie) {
    final isActive = movie['is_active'] ?? false;

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                movie['poster_url'] ?? '',
                width: 80,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 80,
                  height: 120,
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
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.green : Colors.grey,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isActive ? 'ACTIVE' : 'INACTIVE',
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
                    '${movie['genre']} â€¢ ${movie['language']} â€¢ ${movie['duration']} min',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${movie['rating']}/10',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    movie['description'] ?? '',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Action Buttons
                  Row(
                    children: [
                      // Toggle Active
                      IconButton(
                        icon: Icon(
                          isActive ? Icons.visibility_off : Icons.visibility,
                          color: isActive ? Colors.orange : Colors.green,
                          size: 20,
                        ),
                        onPressed: () => _toggleActive(movie['id'], isActive),
                        tooltip: isActive ? 'Deactivate' : 'Activate',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 16),

                      // Edit
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.blue,
                          size: 20,
                        ),
                        onPressed: () => _showAddEditDialog(movie: movie),
                        tooltip: 'Edit',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 16),

                      // Delete
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.red,
                          size: 20,
                        ),
                        onPressed: () =>
                            _deleteMovie(movie['id'], movie['title']),
                        tooltip: 'Delete',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
