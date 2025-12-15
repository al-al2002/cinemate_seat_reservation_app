import 'dart:async';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Service for managing user online status using Supabase directly
class OnlineStatusService {
  static OnlineStatusService? _instance;
  static OnlineStatusService get instance {
    _instance ??= OnlineStatusService._();
    return _instance!;
  }

  OnlineStatusService._();

  Timer? _heartbeatTimer;
  String? _currentUserId;
  bool _isCurrentlyOnline = false;
  bool _isUpdating = false;

  /// Check if user is currently marked as online
  bool get isOnline => _isCurrentlyOnline;

  /// Update user online status in Supabase users table
  Future<bool> updateOnlineStatus({
    required String userId,
    required bool isOnline,
  }) async {
    // Prevent duplicate updates
    if (_isCurrentlyOnline == isOnline && _currentUserId == userId) {
      return true;
    }

    // Prevent concurrent updates
    if (_isUpdating) return false;
    _isUpdating = true;

    try {
      await SupabaseService.client
          .from('users')
          .update({
            'is_online': isOnline,
            'last_seen': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId);

      _isCurrentlyOnline = isOnline;
      debugPrint('Online status updated: $isOnline for user $userId');
      return true;
    } catch (e) {
      debugPrint('Error updating online status: $e');
      return false;
    } finally {
      _isUpdating = false;
    }
  }

  /// Send heartbeat to update last_seen timestamp
  Future<bool> sendHeartbeat(String userId) async {
    try {
      await SupabaseService.client
          .from('users')
          .update({
            'is_online': true,
            'last_seen': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId);

      debugPrint('Heartbeat sent for user $userId');
      return true;
    } catch (e) {
      debugPrint('Error sending heartbeat: $e');
      return false;
    }
  }

  /// Start heartbeat timer (call after successful login)
  void startHeartbeat(String userId) {
    // Already running heartbeat for this user
    if (_heartbeatTimer != null && _currentUserId == userId) {
      return;
    }

    _currentUserId = userId;

    // Cancel any existing timer
    _heartbeatTimer?.cancel();

    // Start periodic heartbeat every 2 minutes
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (_currentUserId != null) {
        sendHeartbeat(_currentUserId!);
      }
    });

    debugPrint('Heartbeat timer started for user $userId');
  }

  /// Stop heartbeat timer (call before logout)
  void stopHeartbeat() {
    if (_heartbeatTimer == null) return; // Already stopped

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    debugPrint('Heartbeat timer stopped');
  }

  /// Handle user login - set online status and start heartbeat
  Future<void> onUserLogin(String userId) async {
    // Skip if already online with same user
    if (_isCurrentlyOnline &&
        _currentUserId == userId &&
        _heartbeatTimer != null) {
      debugPrint('User $userId already online, skipping');
      return;
    }
    await updateOnlineStatus(userId: userId, isOnline: true);
    startHeartbeat(userId);
  }

  /// Handle user logout - set offline status and stop heartbeat
  Future<void> onUserLogout(String userId) async {
    // Skip if already offline
    if (!_isCurrentlyOnline && _heartbeatTimer == null) {
      debugPrint('User already offline, skipping');
      return;
    }
    stopHeartbeat();
    await updateOnlineStatus(userId: userId, isOnline: false);
    _currentUserId = null;
    _isCurrentlyOnline = false;
  }

  /// Dispose resources
  void dispose() {
    stopHeartbeat();
    _currentUserId = null;
  }
}
