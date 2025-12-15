import 'package:flutter/material.dart';

class AppColors {
  // Netflix-inspired Black & Red theme
  static const Color primary = Color(0xFFE50914); // Netflix Red
  static const Color secondary = Color(0xFFB20710); // Dark Red
  static const Color accent = Color(0xFFE50914); // Netflix Red

  static const Color background = Color(0xFF141414); // Netflix Black
  static const Color surface = Color(0xFF1F1F1F); // Dark Grey
  static const Color surfaceLight = Color(0xFF2A2A2A); // Light Grey
  static const Color error = Color(0xFFE50914);

  // Seat colors - Netflix style
  static const Color seatAvailable = Color(0xFF808080); // Grey
  static const Color seatReserved = Color(0xFFFFB800); // Gold/Yellow
  static const Color seatPaid = Color(0xFFE50914); // Netflix Red
  static const Color seatSelected = Color(0xFF46D369); // Green

  // Seat type colors - Netflix style
  static const Color seatRegular = Color(0xFF565656);
  static const Color seatVip = Color(0xFFFFB800);
  static const Color seatPremium = Color(0xFFE50914);

  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textMuted = Color(0xFF808080);
}

class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

class AppConstants {
  // Colors - Netflix theme
  static const Color primaryColor = Color(0xFFE50914); // Netflix Red
  static const Color secondaryColor = Color(0xFF141414); // Netflix Black
  static const Color accentColor = Color(0xFFE50914); // Netflix Red

  static const String appName = 'Cinemate';
  static const int reservationExpiryMinutes = 15;
  static const double defaultTicketPrice = 250.0; // PHP
  static const double vipPriceMultiplier = 1.5;
  static const double premiumPriceMultiplier = 2.0;

  // Payment methods
  static const List<String> paymentMethods = ['GCash', 'Maya', 'Credit Card'];

  // Movie genres
  static const List<String> genres = [
    'Action',
    'Comedy',
    'Drama',
    'Horror',
    'Romance',
    'Sci-Fi',
    'Thriller',
    'Fantasy',
    'Historical',
    'Documentary',
  ];

  // Languages
  static const List<String> languages = [
    'Tagalog',
    'English',
    'Bisaya',
    'Ilocano',
    'Korean',
    'Japanese',
    'Chinese',
  ];

  // Movie ratings (MTRCB)
  static const List<String> ratings = [
    'G', // General Audiences
    'PG', // Parental Guidance
    'PG-13', // Parental Guidance for children below 13
    'R-13', // Restricted to 13 years and above
    'R-16', // Restricted to 16 years and above
    'R-18', // Restricted to 18 years and above
  ];
}
