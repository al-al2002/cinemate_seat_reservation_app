import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/supabase_service.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/profile/tickets_screen.dart';
import '../screens/profile/reservations_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/movie/movie_details_screen.dart';
import '../screens/booking/seat_selection_screen.dart';
import '../screens/payment/payment_screen.dart';
import '../screens/ticket/ticket_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/movies_management_screen.dart';
import '../screens/admin/showtimes_management_screen.dart';
import '../screens/admin/bookings_management_screen.dart';

/// App Router - Centralized navigation configuration
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,

    // Redirect logic based on authentication state
    redirect: (context, state) {
      final isAuthenticated = SupabaseService.isAuthenticated;
      final isLoggingIn =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      // If not authenticated and trying to access protected route
      if (!isAuthenticated && !isLoggingIn) {
        return '/login';
      }

      // If authenticated and on login/register, redirect to dashboard
      if (isAuthenticated && isLoggingIn) {
        return '/dashboard';
      }

      // No redirect needed
      return null;
    },

    routes: [
      // ==========================================
      // AUTH ROUTES
      // ==========================================
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // ==========================================
      // MAIN APP ROUTES (with Bottom Navigation)
      // ==========================================
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),

      // Movie Details (no bottom nav)
      GoRoute(
        path: '/movie/:movieId',
        name: 'movie-details',
        builder: (context, state) {
          final movieId = state.pathParameters['movieId']!;
          return MovieDetailsScreen(movieId: movieId);
        },
      ),

      // Seat Selection
      GoRoute(
        path: '/seats/:showtimeId',
        name: 'seat-selection',
        builder: (context, state) {
          final showtimeId = state.pathParameters['showtimeId']!;
          return SeatSelectionScreen(showtimeId: showtimeId);
        },
      ),

      // Payment
      GoRoute(
        path: '/payment/:showtimeId',
        name: 'payment',
        builder: (context, state) {
          final showtimeId = state.pathParameters['showtimeId']!;
          final selectedSeatIds =
              state.uri.queryParameters['seats']?.split(',') ?? [];
          return PaymentScreen(
            showtimeId: showtimeId,
            selectedSeatIds: selectedSeatIds,
          );
        },
      ),

      // Ticket
      GoRoute(
        path: '/ticket/:ticketId',
        name: 'ticket',
        builder: (context, state) {
          final ticketId = state.pathParameters['ticketId']!;
          return TicketScreen(ticketId: ticketId);
        },
      ),

      // ==========================================
      // PROFILE ROUTES (with Bottom Navigation)
      // ==========================================
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/my-tickets',
        name: 'my-tickets',
        builder: (context, state) => const TicketsScreen(),
      ),
      GoRoute(
        path: '/my-reservations',
        name: 'my-reservations',
        builder: (context, state) => const ReservationsScreen(),
      ),

      // ==========================================
      // ADMIN ROUTES
      // ==========================================
      GoRoute(
        path: '/admin',
        name: 'admin-dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/movies',
        name: 'admin-movies',
        builder: (context, state) => const MoviesManagementScreen(),
      ),
      GoRoute(
        path: '/admin/showtimes',
        name: 'admin-showtimes',
        builder: (context, state) => const ShowtimesManagementScreen(),
      ),
      GoRoute(
        path: '/admin/bookings',
        name: 'admin-bookings',
        builder: (context, state) => const BookingsManagementScreen(),
      ),
    ],

    // Error handling
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 80),
            const SizedBox(height: 20),
            const Text(
              '404',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Page Not Found',
              style: TextStyle(fontSize: 20, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: const Text('Go to Dashboard'),
            ),
          ],
        ),
      ),
    ),
  );
}
