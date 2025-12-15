import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class MovieFilters extends StatefulWidget {
  final List<String> selectedGenres;
  final List<String> selectedLanguages;
  final List<String> selectedRatings;
  final Function(List<String>) onGenresChanged;
  final Function(List<String>) onLanguagesChanged;
  final Function(List<String>) onRatingsChanged;
  final VoidCallback onClearAll;

  const MovieFilters({
    super.key,
    required this.selectedGenres,
    required this.selectedLanguages,
    required this.selectedRatings,
    required this.onGenresChanged,
    required this.onLanguagesChanged,
    required this.onRatingsChanged,
    required this.onClearAll,
  });

  @override
  State<MovieFilters> createState() => _MovieFiltersState();
}

class _MovieFiltersState extends State<MovieFilters> {
  bool _showFilters = false;

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters =
        widget.selectedGenres.isNotEmpty ||
        widget.selectedLanguages.isNotEmpty ||
        widget.selectedRatings.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter Toggle Button
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _showFilters = !_showFilters);
              },
              icon: Icon(
                _showFilters ? Icons.filter_list_off : Icons.filter_list,
              ),
              label: Text(_showFilters ? 'Hide Filters' : 'Show Filters'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _showFilters
                    ? AppConstants.primaryColor
                    : const Color(0xFF2A2A2A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            if (hasActiveFilters) ...[
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: widget.onClearAll,
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Clear All'),
                style: TextButton.styleFrom(
                  foregroundColor: AppConstants.primaryColor,
                ),
              ),
            ],
          ],
        ),

        // Filters Panel
        if (_showFilters) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Genre Filters
                _buildFilterSection(
                  title: 'Genre',
                  icon: Icons.category_outlined,
                  items: AppConstants.genres,
                  selectedItems: widget.selectedGenres,
                  onChanged: widget.onGenresChanged,
                ),
                const SizedBox(height: 16),

                // Language Filters
                _buildFilterSection(
                  title: 'Language',
                  icon: Icons.language_outlined,
                  items: AppConstants.languages,
                  selectedItems: widget.selectedLanguages,
                  onChanged: widget.onLanguagesChanged,
                ),
                const SizedBox(height: 16),

                // Rating Filters
                _buildFilterSection(
                  title: 'Rating (MTRCB)',
                  icon: Icons.star_outline,
                  items: AppConstants.ratings,
                  selectedItems: widget.selectedRatings,
                  onChanged: widget.onRatingsChanged,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFilterSection({
    required String title,
    required IconData icon,
    required List<String> items,
    required List<String> selectedItems,
    required Function(List<String>) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppConstants.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) {
            final isSelected = selectedItems.contains(item);
            return FilterChip(
              label: Text(item),
              selected: isSelected,
              onSelected: (selected) {
                final newSelection = List<String>.from(selectedItems);
                if (selected) {
                  newSelection.add(item);
                } else {
                  newSelection.remove(item);
                }
                onChanged(newSelection);
              },
              backgroundColor: const Color(0xFF2A2A2A),
              selectedColor: AppConstants.primaryColor.withOpacity(0.3),
              checkmarkColor: AppConstants.primaryColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFFB3B3B3),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected
                    ? AppConstants.primaryColor
                    : Colors.white.withOpacity(0.2),
                width: isSelected ? 2 : 1,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
