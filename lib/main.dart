import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cineme_seat_reservation_app/services/supabase_service.dart';
import 'package:cineme_seat_reservation_app/services/online_status_service.dart';
import 'package:cineme_seat_reservation_app/services/payment_service.dart';
import 'package:cineme_seat_reservation_app/constants/app_constants.dart';
import 'package:cineme_seat_reservation_app/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Supabase
  await SupabaseService.initialize();

  // Run cleanup tasks for expired reservations/tickets on app start
  SupabaseService.runCleanupTasks().then((results) {
    if (results['reservations']! > 0 || results['tickets']! > 0) {
      debugPrint(
        'Cleanup completed: ${results['reservations']} reservations, ${results['tickets']} tickets expired',
      );
    }
  });

  // Sync paid tickets with their seats (fix any seats not marked as paid)
  PaymentService.syncPaidTicketSeats().then((count) {
    if (count > 0) {
      debugPrint('Synced $count seats from paid tickets');
    }
  });

  // If user is already logged in, start heartbeat
  final currentUser = SupabaseService.client.auth.currentUser;
  if (currentUser != null) {
    OnlineStatusService.instance.onUserLogin(currentUser.id);
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    OnlineStatusService.instance.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;

    // Only handle actual app pause/resume, not intermediate states
    if (state == AppLifecycleState.resumed) {
      // App came to foreground - set online and restart heartbeat
      OnlineStatusService.instance.onUserLogin(userId);
      debugPrint('App resumed - user online');
    } else if (state == AppLifecycleState.paused) {
      // App went to background - set offline and stop heartbeat
      OnlineStatusService.instance.onUserLogout(userId);
      debugPrint('App paused - user offline');
    }
    // Ignore inactive, detached, hidden states to prevent duplicate calls
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      routerConfig: AppRouter.router,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppConstants.secondaryColor, // Netflix Black
        colorScheme: ColorScheme.dark(
          primary: AppConstants.primaryColor, // Netflix Red
          secondary: AppConstants.primaryColor,
          surface: const Color(0xFF1F1F1F), // Dark Grey
          background: AppConstants.secondaryColor, // Netflix Black
          error: AppConstants.primaryColor,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppConstants.secondaryColor,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(color: const Color(0xFF1F1F1F), elevation: 4),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: AppConstants.primaryColor, width: 2),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Color(0xFFB3B3B3)),
        ),
        useMaterial3: true,
      ),
    );
  }
}
