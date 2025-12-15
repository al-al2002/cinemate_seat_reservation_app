import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/app_constants.dart';
import '../../services/supabase_service.dart';

class ShowtimesManagementScreen extends StatefulWidget {
  const ShowtimesManagementScreen({super.key});

  @override
  State<ShowtimesManagementScreen> createState() =>
      _ShowtimesManagementScreenState();
}

class _ShowtimesManagementScreenState extends State<ShowtimesManagementScreen> {
  List<Map<String, dynamic>> _showtimes = [];
  List<Map<String, dynamic>> _filteredShowtimes = [];
  List<Map<String, dynamic>> _movies = [];
  bool _isLoading = true;
  String _filterMovie = 'All';
  String _filterCinema = 'All';
  DateTime _selectedDate = DateTime.now();

  final List<String> _cinemaHalls = [
    'All',
    'Cinema 1',
    'Cinema 2',
    'Cinema 3',
    'Cinema 4',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load movies for dropdown
      final moviesResponse = await SupabaseService.client
          .from('movies')
          .select()
          .eq('is_active', true)
          .order('title');

      // Load showtimes with movie details
      final showtimesResponse = await SupabaseService.client
          .from('showtimes')
          .select('''
            *,
            movies (
              id,
              title,
              poster_url,
              duration_minutes
            )
          ''')
          .order('showtime', ascending: true);

      setState(() {
        _movies = List<Map<String, dynamic>>.from(moviesResponse);
        _showtimes = List<Map<String, dynamic>>.from(showtimesResponse);
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
      _filteredShowtimes = _showtimes.where((showtime) {
        final showtimeDate = DateTime.parse(showtime['showtime']);
        final dateMatches =
            showtimeDate.year == _selectedDate.year &&
            showtimeDate.month == _selectedDate.month &&
            showtimeDate.day == _selectedDate.day;

        final movieMatches =
            _filterMovie == 'All' ||
            showtime['movie_id'].toString() == _filterMovie;

        final cinemaMatches =
            _filterCinema == 'All' || showtime['cinema_hall'] == _filterCinema;

        return dateMatches && movieMatches && cinemaMatches;
      }).toList();
    });
  }

  Future<void> _showAddEditDialog({Map<String, dynamic>? showtime}) async {
    final isEdit = showtime != null;
    String? selectedMovieId = showtime?['movie_id']?.toString();
    String selectedCinema = showtime?['cinema_hall'] ?? 'Cinema 1';
    DateTime selectedDate = showtime != null
        ? DateTime.parse(showtime['showtime'])
        : DateTime.now();
    TimeOfDay selectedTime = showtime != null
        ? TimeOfDay.fromDateTime(DateTime.parse(showtime['showtime']))
        : TimeOfDay.now();
    final priceController = TextEditingController(
      text: showtime?['base_price']?.toString() ?? '250',
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.background,
          title: Text(
            isEdit ? 'Edit Showtime' : 'Add New Showtime',
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Movie Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedMovieId,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Movie *',
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
                    items: _movies.map((movie) {
                      return DropdownMenuItem<String>(
                        value: movie['id'].toString(),
                        child: Text(
                          movie['title'],
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedMovieId = value);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Cinema Hall Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedCinema,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Cinema Hall *',
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
                    items: _cinemaHalls
                        .where((hall) => hall != 'All')
                        .map(
                          (hall) =>
                              DropdownMenuItem(value: hall, child: Text(hall)),
                        )
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedCinema = value!);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Date Picker
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppConstants.primaryColor,
                                surface: AppColors.surface,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (date != null) {
                        setDialogState(() => selectedDate = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[700]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Date: ${DateFormat('MMM dd, yyyy').format(selectedDate)}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          const Icon(Icons.calendar_today, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Time Picker
                  InkWell(
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppConstants.primaryColor,
                                surface: AppColors.surface,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (time != null) {
                        setDialogState(() => selectedTime = time);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[700]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Time: ${selectedTime.format(context)}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          const Icon(Icons.access_time, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Base Price
                  TextField(
                    controller: priceController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Base Price (₱) *',
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
              onPressed: () => _saveShowtime(
                showtime?['id'],
                selectedMovieId,
                selectedCinema,
                selectedDate,
                selectedTime,
                priceController.text,
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

  Future<void> _saveShowtime(
    String? id,
    String? movieId,
    String cinemaHall,
    DateTime date,
    TimeOfDay time,
    String price,
  ) async {
    // Validation
    if (movieId == null || price.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final basePrice = double.tryParse(price);
    if (basePrice == null || basePrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid price'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Combine date and time
    final showtime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    // Check if showtime is in the past
    if (showtime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot create showtime in the past'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final showtimeData = {
        'movie_id': movieId,
        'cinema_hall': cinemaHall,
        'showtime': showtime.toIso8601String(),
        'base_price': basePrice,
      };

      if (id == null) {
        // Add new showtime
        final response = await SupabaseService.client
            .from('showtimes')
            .insert(showtimeData)
            .select()
            .single();

        // Generate seats for the new showtime
        await _generateSeats(response['id'], cinemaHall);
      } else {
        // Update existing showtime
        await SupabaseService.client
            .from('showtimes')
            .update(showtimeData)
            .eq('id', id);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              id == null
                  ? 'Showtime added successfully!'
                  : 'Showtime updated successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving showtime: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateSeats(String showtimeId, String cinemaHall) async {
    try {
      // Standard cinema layout: 10 rows (A-J), 12 seats per row
      const rows = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J'];
      const seatsPerRow = 12;

      final seats = <Map<String, dynamic>>[];

      for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
        for (var seatNumber = 1; seatNumber <= seatsPerRow; seatNumber++) {
          // Determine seat type
          String seatType = 'regular';
          if (rowIndex >= 7) {
            // Last 3 rows are premium
            seatType = 'premium';
          } else if (rowIndex >= 4 && seatNumber >= 4 && seatNumber <= 9) {
            // Middle rows, center seats are VIP
            seatType = 'vip';
          }

          seats.add({
            'showtime_id': showtimeId,
            'seat_row': rows[rowIndex],
            'row_label':
                rows[rowIndex], // Also set row_label (both columns exist!)
            'seat_number': seatNumber,
            'seat_type': seatType,
            'status': 'available',
          });
        }
      }

      // Insert all seats
      await SupabaseService.client.from('seats').insert(seats);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating seats: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteShowtime(
    String id,
    String movieTitle,
    String showtime,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        title: const Text(
          'Delete Showtime',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete this showtime for "$movieTitle"?\n\n'
          'This will also delete all associated seats and may affect existing bookings.',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Delete seats first (cascade)
        await SupabaseService.client
            .from('seats')
            .delete()
            .eq('showtime_id', id);

        // Delete showtime
        await SupabaseService.client.from('showtimes').delete().eq('id', id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Showtime deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting showtime: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _duplicateShowtime(Map<String, dynamic> showtime) async {
    // Show dialog to select new date/time
    DateTime newDate = DateTime.now();
    TimeOfDay newTime = TimeOfDay.now();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.background,
          title: const Text(
            'Duplicate Showtime',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select new date and time for:\n${showtime['movies']['title']}',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: newDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: AppConstants.primaryColor,
                            surface: AppColors.surface,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (date != null) {
                    setDialogState(() => newDate = date);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[700]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('MMM dd, yyyy').format(newDate),
                        style: const TextStyle(color: Colors.white),
                      ),
                      const Icon(Icons.calendar_today, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: newTime,
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: AppConstants.primaryColor,
                            surface: AppColors.surface,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (time != null) {
                    setDialogState(() => newTime = time);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[700]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        newTime.format(context),
                        style: const TextStyle(color: Colors.white),
                      ),
                      const Icon(Icons.access_time, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, {'date': newDate, 'time': newTime}),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
              ),
              child: const Text('Duplicate'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await _saveShowtime(
        null, // New showtime
        showtime['movie_id'],
        showtime['cinema_hall'],
        result['date'],
        result['time'],
        showtime['base_price'].toString(),
      );
    }
  }

  Future<int> _getSeatAvailability(String showtimeId) async {
    try {
      final response = await SupabaseService.client
          .from('seats')
          .select()
          .eq('showtime_id', showtimeId)
          .eq('status', 'available');

      return response.length;
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Showtime Management'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: Column(
              children: [
                // Date selector
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 30),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                      builder: (context, child) {
                        return Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: AppConstants.primaryColor,
                              surface: AppColors.surface,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (date != null) {
                      setState(() {
                        _selectedDate = date;
                        _applyFilters();
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: AppConstants.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            DateFormat(
                              'EEEE, MMMM dd, yyyy',
                            ).format(_selectedDate),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.grey,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterMovie,
                        dropdownColor: AppColors.surface,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Movie',
                          labelStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                            value: 'All',
                            child: Text(
                              'All Movies',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ..._movies.map(
                            (movie) => DropdownMenuItem(
                              value: movie['id'].toString(),
                              child: Text(
                                movie['title'],
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _filterMovie = value!;
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterCinema,
                        dropdownColor: AppColors.surface,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Cinema',
                          labelStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        isExpanded: true,
                        items: _cinemaHalls
                            .map(
                              (hall) => DropdownMenuItem(
                                value: hall,
                                child: Text(
                                  hall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _filterCinema = value!;
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
                  '${_filteredShowtimes.length} showtimes found',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                Text(
                  'Total: ${_showtimes.length}',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
          ),

          // Showtimes List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppConstants.primaryColor,
                    ),
                  )
                : _filteredShowtimes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 64,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No showtimes found',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try selecting a different date',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredShowtimes.length,
                    itemBuilder: (context, index) {
                      final showtime = _filteredShowtimes[index];
                      return _buildShowtimeCard(showtime);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppConstants.primaryColor,
        icon: const Icon(Icons.add),
        label: const Text('Add Showtime'),
      ),
    );
  }

  Widget _buildShowtimeCard(Map<String, dynamic> showtime) {
    final movie = showtime['movies'];
    final showtimeDate = DateTime.parse(showtime['showtime']);
    final timeString = DateFormat('hh:mm a').format(showtimeDate);

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
                  Text(
                    movie['title'] ?? 'Untitled',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeString,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.meeting_room,
                        size: 16,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        showtime['cinema_hall'],
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.currency_exchange,
                        size: 16,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '₱${showtime['base_price']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.event_seat, size: 16, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      FutureBuilder<int>(
                        future: _getSeatAvailability(showtime['id']),
                        builder: (context, snapshot) {
                          final available = snapshot.data ?? 0;
                          return Text(
                            '$available seats available',
                            style: TextStyle(
                              color: available > 0 ? Colors.green : Colors.red,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Action Buttons
                  Row(
                    children: [
                      // Duplicate
                      IconButton(
                        icon: const Icon(
                          Icons.content_copy,
                          color: Colors.blue,
                          size: 20,
                        ),
                        onPressed: () => _duplicateShowtime(showtime),
                        tooltip: 'Duplicate',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 16),

                      // Edit
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.orange,
                          size: 20,
                        ),
                        onPressed: () => _showAddEditDialog(showtime: showtime),
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
                        onPressed: () => _deleteShowtime(
                          showtime['id'],
                          movie['title'],
                          timeString,
                        ),
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
