import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../models/study_session.dart';

class Back4AppService {
  // Add caching mechanism
  static List<StudySession> _cachedSessions = [];

  // User Authentication
  static Future<Map<String, dynamic>> signUp(
    String username,
    String email,
    String password,
  ) async {
    final user = ParseUser.createUser(username, password, email);

    try {
      var response = await user.signUp();
      if (response.success) {
        // After signup, the user is automatically set as the current user
        await ParseUser(username, password, email).login();
        return {'success': true, 'user': user};
      } else {
        return {'success': false, 'error': response.error?.message};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    final user = ParseUser(username, password, null);

    try {
      var response = await user.login();
      if (response.success) {
        // User is automatically set as current user after login
        return {'success': true, 'user': user};
      } else {
        return {'success': false, 'error': response.error?.message};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Add password reset functionality
  static Future<Map<String, dynamic>> resetPassword(String email) async {
    try {
      final user = ParseUser(null, null, email);
      final response = await user.requestPasswordReset();

      if (response.success) {
        return {'success': true};
      } else {
        return {
          'success': false,
          'error':
              response.error?.message ?? 'Failed to send password reset email',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: Please check your connection',
      };
    }
  }

  // Session validation helper
  static Future<bool> validateSession() async {
    try {
      final user = await ParseUser.currentUser() as ParseUser?;
      if (user == null) return false;

      // Verify token is still valid
      final sessionToken = user.sessionToken;
      return sessionToken != null && sessionToken.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> logout() async {
    try {
      final user = await ParseUser.currentUser() as ParseUser?;
      if (user == null) return true; // Already logged out

      // Clear any cached data
      _cachedSessions = [];

      var response = await user.logout();
      return response.success;
    } catch (e) {
      return false;
    }
  }

  // Study Session CRUD Operations
  static Future<Map<String, dynamic>> addStudySession(
    String subject,
    int duration, {
    String notes = '',
  }) async {
    try {
      // Validate session first
      if (!await validateSession()) {
        return {
          'success': false,
          'error': 'Session expired. Please login again.',
          'sessionExpired': true,
        };
      }

      final currentUser = await ParseUser.currentUser() as ParseUser;

      var studySession =
          StudySession()
            ..subject = subject
            ..duration = duration
            ..notes = notes
            ..user = currentUser;

      var response = await studySession.save();

      if (response.success) {
        // Add to local cache
        _cachedSessions.insert(0, studySession);
        return {'success': true, 'session': studySession};
      } else {
        if (response.error?.code == 209) {
          // Invalid session token
          return {
            'success': false,
            'error': 'Session expired. Please login again.',
            'sessionExpired': true,
          };
        }
        return {'success': false, 'error': response.error?.message};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<List<StudySession>> getStudySessions({int skip = 0}) async {
    try {
      // Validate session first
      if (!await validateSession()) {
        return [];
      }

      // Return cached data immediately if available and not paginating
      if (_cachedSessions.isNotEmpty && skip == 0) {
        // Refresh cache in background
        _refreshCacheInBackground();
        return _cachedSessions;
      }

      final currentUser = await ParseUser.currentUser() as ParseUser;

      final queryBuilder =
          QueryBuilder<StudySession>(StudySession())
            ..whereEqualTo('user', currentUser)
            ..orderByDescending('createdAt')
            ..setAmountToSkip(skip);

      final response = await queryBuilder.query();

      if (response.success && response.results != null) {
        final sessions =
            response.results!.map((e) => e as StudySession).toList();
        // Update cache if this is the first page
        if (skip == 0) {
          _cachedSessions = sessions;
        }
        return sessions;
      }
    } catch (e) {
      // Log error but don't crash
    }

    return [];
  }

  // Study statistics by day of the week
  static Future<Map<String, int>> getStudyStatsByDayOfWeek() async {
    final Map<String, int> dayStats = {
      'Monday': 0,
      'Tuesday': 0,
      'Wednesday': 0,
      'Thursday': 0,
      'Friday': 0,
      'Saturday': 0,
      'Sunday': 0,
    };

    try {
      final sessions = await getStudySessions();

      for (final session in sessions) {
        final dayOfWeek = _getDayOfWeek(session.createdAt);
        dayStats[dayOfWeek] = (dayStats[dayOfWeek] ?? 0) + session.duration;
      }

      return dayStats;
    } catch (e) {
      return dayStats;
    }
  }

  // Get current study streak
  static Future<int> getCurrentStreak() async {
    try {
      final sessions = await getStudySessions();
      if (sessions.isEmpty) return 0;

      // Sort sessions by date (newest first is the default)
      final dates =
          sessions.map((s) => _dateOnly(s.createdAt)).toSet().toList();
      dates.sort((a, b) => b.compareTo(a)); // Sort newest to oldest

      // Count streak (consecutive days)
      int streak = 1; // Start with the most recent day
      final today = _dateOnly(DateTime.now());

      // Check if studied today
      if (dates.isEmpty || dates[0] != today) {
        // Check if studied yesterday to continue streak
        final yesterday = _dateOnly(
          DateTime.now().subtract(const Duration(days: 1)),
        );
        if (dates.isEmpty || dates[0] != yesterday) {
          return 0; // Streak broken
        }
      }

      // Count consecutive days
      for (int i = 0; i < dates.length - 1; i++) {
        final currentDate = dates[i];
        final nextDate = dates[i + 1];

        // Check if dates are consecutive
        final difference = currentDate.difference(nextDate).inDays;
        if (difference == 1) {
          streak++;
        } else {
          break; // Streak ends
        }
      }

      return streak;
    } catch (e) {
      return 0;
    }
  }

  // Helper to get date only (without time) for streak calculation
  static DateTime _dateOnly(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  // Helper to get day of week name
  static String _getDayOfWeek(DateTime date) {
    switch (date.weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Unknown';
    }
  }

  // Refresh cache in background
  static Future<void> _refreshCacheInBackground() async {
    try {
      if (!await validateSession()) return;

      final currentUser = await ParseUser.currentUser() as ParseUser?;
      if (currentUser == null) return;

      final queryBuilder =
          QueryBuilder<StudySession>(StudySession())
            ..whereEqualTo('user', currentUser)
            ..orderByDescending('createdAt');

      final response = await queryBuilder.query();

      if (response.success && response.results != null) {
        _cachedSessions =
            response.results!.map((e) => e as StudySession).toList();
      }
    } catch (e) {
      // Silent catch - just maintain existing cache
    }
  }

  static Future<Map<String, dynamic>> updateStudySession(
    StudySession session,
    String subject,
    int duration, {
    String? notes,
  }) async {
    try {
      // Validate session first
      if (!await validateSession()) {
        return {
          'success': false,
          'error': 'Session expired. Please login again.',
          'sessionExpired': true,
        };
      }

      session.subject = subject;
      session.duration = duration;

      // Only update notes if provided
      if (notes != null) {
        session.notes = notes;
      }

      var response = await session.save();

      if (response.success) {
        // Update in cache if present
        final index = _cachedSessions.indexWhere(
          (s) => s.objectId == session.objectId,
        );
        if (index >= 0) {
          _cachedSessions[index] = session;
        }
        return {'success': true, 'session': session};
      } else {
        if (response.error?.code == 209) {
          // Invalid session token
          return {
            'success': false,
            'error': 'Session expired. Please login again.',
            'sessionExpired': true,
          };
        }
        return {'success': false, 'error': response.error?.message};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteStudySession(
    StudySession session,
  ) async {
    try {
      // Validate session first
      if (!await validateSession()) {
        return {
          'success': false,
          'error': 'Session expired. Please login again.',
          'sessionExpired': true,
        };
      }

      var response = await session.delete();

      if (response.success) {
        // Remove from cache if present
        _cachedSessions.removeWhere((s) => s.objectId == session.objectId);
        return {'success': true};
      } else {
        if (response.error?.code == 209) {
          // Invalid session token
          return {
            'success': false,
            'error': 'Session expired. Please login again.',
            'sessionExpired': true,
          };
        }
        return {'success': false, 'error': response.error?.message};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
