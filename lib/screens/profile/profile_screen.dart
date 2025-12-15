import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import '../../services/online_status_service.dart';
import '../../constants/app_constants.dart';
import '../../widgets/custom_bottom_nav.dart';
import '../profile/tickets_screen.dart';
import '../profile/reservations_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _userName;
  String? _userEmail;
  int _ticketCount = 0;
  int _reservationCount = 0;
  bool _isLoading = true;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user != null) {
        setState(() {
          _userEmail = user.email;
          _userName = user.email?.split('@').first ?? 'User';
        });

        // Load ticket count
        final ticketsResponse = await SupabaseService.tickets.select().eq(
          'user_id',
          user.id,
        );

        // Load reservation count
        final reservationsResponse = await SupabaseService.reservations
            .select()
            .eq('user_id', user.id)
            .neq('status', 'cancelled');

        setState(() {
          _ticketCount = (ticketsResponse as List).length;
          _reservationCount = (reservationsResponse as List).length;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: AppConstants.primaryColor,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadUserData,
                  color: AppConstants.primaryColor,
                  backgroundColor: const Color(0xFF1F1F1F),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        // User Info Card
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppConstants.primaryColor,
                                AppConstants.primaryColor.withOpacity(0.7),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppConstants.primaryColor.withOpacity(
                                  0.3,
                                ),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Avatar
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    _userName?.substring(0, 1).toUpperCase() ??
                                        'U',
                                    style: TextStyle(
                                      color: AppConstants.primaryColor,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Name
                              Text(
                                _userName ?? 'User',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Email
                              Text(
                                _userEmail ?? '',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Stats
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildStatItem('Tickets', _ticketCount),
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: Colors.white30,
                                  ),
                                  _buildStatItem(
                                    'Reservations',
                                    _reservationCount,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Menu Items
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              _buildMenuSection('My Bookings', [
                                _buildMenuItem(
                                  icon: Icons.confirmation_number,
                                  title: 'My Tickets',
                                  subtitle: 'View all your movie tickets',
                                  color: Colors.green,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const TicketsScreen(),
                                      ),
                                    );
                                  },
                                ),
                                _buildMenuItem(
                                  icon: Icons.event_seat,
                                  title: 'My Reservations',
                                  subtitle: 'Manage pending reservations',
                                  color: Colors.orange,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const ReservationsScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ]),

                              const SizedBox(height: 16),

                              _buildMenuSection('Coming Soon', [
                                _buildMenuItem(
                                  icon: Icons.favorite,
                                  title: 'Favorites',
                                  subtitle: 'Your favorite movies',
                                  color: Colors.pink,
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Coming soon!'),
                                        backgroundColor: Colors.pink,
                                      ),
                                    );
                                  },
                                ),
                                _buildMenuItem(
                                  icon: Icons.history,
                                  title: 'Booking History',
                                  subtitle: 'View all past bookings',
                                  color: Colors.blue,
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Coming soon!'),
                                        backgroundColor: Colors.blue,
                                      ),
                                    );
                                  },
                                ),
                              ]),

                              const SizedBox(height: 16),

                              _buildMenuSection('Account', [
                                _buildMenuItem(
                                  icon: Icons.settings,
                                  title: 'Settings',
                                  subtitle: 'App preferences',
                                  color: Colors.grey,
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Coming soon!'),
                                        backgroundColor: Colors.grey,
                                      ),
                                    );
                                  },
                                ),
                                // Admin Panel - Hidden for now
                                // _buildMenuItem(
                                //   icon: Icons.admin_panel_settings,
                                //   title: 'Admin Panel',
                                //   subtitle: 'Manage movies and bookings',
                                //   color: Colors.deepPurple,
                                //   onTap: () {
                                //     context.push('/admin');
                                //   },
                                // ),
                                _buildMenuItem(
                                  icon: Icons.help_outline,
                                  title: 'Help & Support',
                                  subtitle: 'Get help and contact us',
                                  color: Colors.purple,
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Coming soon!'),
                                        backgroundColor: Colors.purple,
                                      ),
                                    );
                                  },
                                ),
                                _buildMenuItem(
                                  icon: Icons.logout,
                                  title: 'Logout',
                                  subtitle: 'Sign out of your account',
                                  color: AppConstants.primaryColor,
                                  onTap: _logout,
                                ),
                              ]),

                              const SizedBox(height: 32),

                              // App Info
                              Text(
                                'Cinemate v1.0.0',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          if (_isLoggingOut)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppConstants.primaryColor),
                    const SizedBox(height: 16),
                    const Text(
                      'Logging out...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNav(currentIndex: 3),
    );
  }

  Widget _buildStatItem(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildMenuSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF808080),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
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
                        fontWeight: FontWeight.w600,
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
              const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF808080),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Color(0xFFB3B3B3)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryColor,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoggingOut = true);

      try {
        // Set user offline status before signing out
        final userId = SupabaseService.client.auth.currentUser?.id;
        if (userId != null) {
          await OnlineStatusService.instance.onUserLogout(userId);
        }

        await SupabaseService.client.auth.signOut();

        if (mounted) {
          context.go('/login');
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoggingOut = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error logging out: ${e.toString()}'),
              backgroundColor: AppConstants.primaryColor,
            ),
          );
        }
      }
    }
  }
}
