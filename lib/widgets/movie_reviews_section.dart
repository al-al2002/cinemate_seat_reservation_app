import 'package:flutter/material.dart';
import '../../models/review.dart';
import '../../services/supabase_service.dart';
import '../../constants/app_constants.dart';

class MovieReviewsSection extends StatefulWidget {
  final String movieId;

  const MovieReviewsSection({super.key, required this.movieId});

  @override
  State<MovieReviewsSection> createState() => _MovieReviewsSectionState();
}

class _MovieReviewsSectionState extends State<MovieReviewsSection> {
  List<Review> _reviews = [];
  bool _isLoading = true;
  double _averageRating = 0.0;
  final Map<String, String> _userNames = {}; // cache userId -> display name
  Review? _myReview;

  @override
  void initState() {
    super.initState();
    _loadReviews();
    _checkIfUserCanReview();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);

    try {
      // Request review rows together with their related user record if available
      final response = await SupabaseService.client
          .from('reviews')
          .select('*, users(id, full_name, email)')
          .eq('movie_id', widget.movieId)
          .order('created_at', ascending: false);

      final reviews = (response as List).map((json) {
        // If the response includes a nested `users` object, merge relevant fields
        if (json is Map && json['users'] is Map) {
          final userMap = json['users'] as Map;
          // Prefer storing/using `full_name` from users if review lacks `user_name`
          json['user_name'] = json['user_name'] ?? userMap['full_name'];
          json['user_email'] = json['user_email'] ?? userMap['email'];
        }
        return Review.fromJson(json);
      }).toList();

      // Fetch real usernames for reviews that don't include `user_name`
      final missingUserIds = reviews
          .where((r) => r.userName == null || r.userName!.isEmpty)
          .map((r) => r.userId)
          .toSet()
          .toList();

      if (missingUserIds.isNotEmpty) {
        try {
          // PostgREST Dart client may not expose `in_` on the builder in some versions.
          // Use `filter('id', 'in', '(...)')` to select users by a list of ids.
          // Fall back to per-user fetch to avoid client compatibility issues
          for (final uid in missingUserIds) {
            try {
              final u = await SupabaseService.client
                  .from('users')
                  .select('id, user_name, full_name, email')
                  .eq('id', uid)
                  .maybeSingle();

              if (u == null) {
                _userNames[uid] = 'Anonymous';
                continue;
              }

              final id = u['id']?.toString();
              if (id == null) {
                _userNames[uid] = 'Anonymous';
                continue;
              }
              // Prefer `user_name`, then `full_name`, then email prefix
              final userNameField = (u['user_name'] as String?)?.trim();
              final fullNameField = (u['full_name'] as String?)?.trim();
              final email = (u['email'] as String?)?.trim();
              if (userNameField != null && userNameField.isNotEmpty) {
                _userNames[id] = userNameField;
              } else if (fullNameField != null && fullNameField.isNotEmpty) {
                _userNames[id] = fullNameField;
              } else if (email != null && email.isNotEmpty) {
                _userNames[id] = email.split('@')[0];
              } else {
                _userNames[id] = 'Anonymous';
              }
            } catch (e) {
              _userNames[uid] = 'Anonymous';
            }
          }
        } catch (e) {
          // ignore user fetch errors: we'll fall back to existing review data
        }
      }

      // Calculate average rating
      if (reviews.isNotEmpty) {
        final totalRating = reviews.fold<int>(
          0,
          (sum, review) => sum + review.rating,
        );
        _averageRating = totalRating / reviews.length;
      }

      setState(() {
        _reviews = reviews;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading reviews: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkIfUserCanReview() async {
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) {
        return;
      }

      // Check if user has already reviewed — store it so we can allow edit
      _myReview = null;
      try {
        final existingReview = await SupabaseService.client
            .from('reviews')
            .select()
            .eq('user_id', user.id)
            .eq('movie_id', widget.movieId)
            .maybeSingle();
        if (existingReview != null) {
          _myReview = Review.fromJson(
            Map<String, dynamic>.from(existingReview as Map),
          );
        }
      } catch (_) {
        _myReview = null;
      }

      // Update UI with any loaded personal review
      setState(() {});
    } catch (e) {
      // ignore errors; no UI state to change
    }
  }

  String _getDisplayName(Review review) {
    if (review.userName != null && review.userName!.isNotEmpty) {
      return review.userName!;
    }
    final cached = _userNames[review.userId];
    if (cached != null && cached.isNotEmpty) return cached;
    if (review.userEmail != null && review.userEmail!.isNotEmpty) {
      return review.userEmail!.split('@')[0];
    }
    return 'Anonymous';
  }

  void _showReviewDialog() {
    int rating = _myReview?.rating ?? 5;
    final reviewController = TextEditingController(
      text: _myReview?.reviewText ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.background,
          title: Text(
            _myReview == null ? 'Write a Review' : 'Edit Review',
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rating',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      rating.toString(),
                      style: const TextStyle(
                        color: AppConstants.primaryColor,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '/ 10',
                      style: TextStyle(color: Colors.grey, fontSize: 20),
                    ),
                  ],
                ),
                Slider(
                  value: rating.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  activeColor: AppConstants.primaryColor,
                  label: rating.toString(),
                  onChanged: (value) {
                    setDialogState(() => rating = value.toInt());
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(10, (index) {
                    return Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: AppConstants.primaryColor,
                      size: 24,
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reviewController,
                  maxLines: 5,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Your Review (optional)',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    hintText: 'Share your thoughts about this movie...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: AppConstants.primaryColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => _submitReview(rating, reviewController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
              ),
              child: const Text(
                'Submit',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReview(int rating, String reviewText) async {
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to review');
      }

      // Try to read user's full name from `users` table to save with the review
      String? nameToSave;
      try {
        final profile = await SupabaseService.client
            .from('users')
            .select('full_name, user_name, email')
            .eq('id', user.id)
            .maybeSingle();
        if (profile != null) {
          nameToSave =
              (profile['user_name'] as String?)?.trim() ??
              (profile['full_name'] as String?)?.trim();
        }
      } catch (_) {}

      final email = SupabaseService.userEmail;
      if (_myReview != null) {
        // update existing review
        await SupabaseService.client
            .from('reviews')
            .update({
              'rating': rating,
              'review_text': reviewText.isEmpty ? null : reviewText,
              'user_name':
                  nameToSave ?? (email != null ? email.split('@')[0] : null),
              'user_email': email,
            })
            .eq('id', _myReview!.id);
      } else {
        await SupabaseService.client.from('reviews').insert({
          'user_id': user.id,
          'movie_id': widget.movieId,
          'rating': rating,
          'review_text': reviewText.isEmpty ? null : reviewText,
          // include user info to avoid Anonymous display
          'user_name':
              nameToSave ?? (email != null ? email.split('@')[0] : null),
          'user_email': email,
        });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadReviews();
        _checkIfUserCanReview();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting review: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with average rating
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reviews & Ratings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_reviews.isNotEmpty)
                  Row(
                    children: [
                      Icon(
                        Icons.star,
                        color: AppConstants.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _averageRating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: AppConstants.primaryColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        ' (${_reviews.length} ${_reviews.length == 1 ? 'review' : 'reviews'})',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                    ],
                  ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _showReviewDialog,
              icon: const Icon(Icons.rate_review, size: 18),
              label: Text(_myReview == null ? 'Write Review' : 'Edit Review'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Reviews list
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(
                color: AppConstants.primaryColor,
              ),
            ),
          )
        else if (_reviews.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 48,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No reviews yet',
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Be the first to review this movie!',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _reviews.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final review = _reviews[index];
              return _buildReviewCard(review);
            },
          ),
      ],
    );
  }

  Widget _buildReviewCard(Review review) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF404040)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info and rating
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppConstants.primaryColor,
                    radius: 20,
                    child: Text(
                      (_getDisplayName(review)[0]).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getDisplayName(review),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        review.timeAgo,
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.star,
                      color: AppConstants.primaryColor,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${review.rating}/10',
                      style: const TextStyle(
                        color: AppConstants.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Review text
          if (review.reviewText != null && review.reviewText!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              review.reviewText!,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
