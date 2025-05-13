// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/study_session.dart';
import '../services/back4app_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _isLoading = true;
  List<StudySession> _allSessions = [];
  Map<String, int> _subjectTotals = {};
  Map<String, int> _dayOfWeekStats = {};
  int _totalStudyTime = 0;
  String _mostStudiedSubject = '';
  int _maxTimeSpent = 0;
  int _currentStreak = 0;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sessions = await Back4AppService.getStudySessions();
      final dayStats = await Back4AppService.getStudyStatsByDayOfWeek();
      final streak = await Back4AppService.getCurrentStreak();

      if (!mounted) return;

      // Calculate statistics
      final Map<String, int> subjectTotals = {};
      int totalTime = 0;

      for (final session in sessions) {
        // Add to subject totals
        if (subjectTotals.containsKey(session.subject)) {
          subjectTotals[session.subject] =
              (subjectTotals[session.subject] ?? 0) + session.duration;
        } else {
          subjectTotals[session.subject] = session.duration;
        }

        // Add to total time
        totalTime += session.duration;
      }

      // Find most studied subject
      String mostStudied = '';
      int maxTime = 0;

      subjectTotals.forEach((subject, time) {
        if (time > maxTime) {
          maxTime = time;
          mostStudied = subject;
        }
      });

      setState(() {
        _allSessions = sessions;
        _subjectTotals = subjectTotals;
        _dayOfWeekStats = dayStats;
        _totalStudyTime = totalTime;
        _mostStudiedSubject = mostStudied;
        _maxTimeSpent = maxTime;
        _currentStreak = streak;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load statistics')),
      );

      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Study Statistics')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadStatistics,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Streak card
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    'Current Streak',
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.local_fire_department,
                                        color:
                                            _currentStreak > 0
                                                ? Colors.orange
                                                : Colors.grey,
                                        size: 32,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '$_currentStreak day${_currentStreak > 1 || _currentStreak == 0 ? 's' : ''}',
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              _currentStreak > 0
                                                  ? Theme.of(
                                                    context,
                                                  ).primaryColor
                                                  : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _currentStreak > 0
                                        ? 'Keep it up! 🎉'
                                        : 'Study today to start a streak!',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color:
                                          _currentStreak > 0
                                              ? Colors.green[700]
                                              : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Overview Card
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Study Overview',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const Divider(),
                              _buildStatItem(
                                'Total study time',
                                '$_totalStudyTime minutes',
                                Icons.access_time,
                              ),
                              _buildStatItem(
                                'Total study sessions',
                                '${_allSessions.length}',
                                Icons.calendar_today,
                              ),
                              _buildStatItem(
                                'Most studied subject',
                                _mostStudiedSubject.isEmpty
                                    ? 'None'
                                    : '$_mostStudiedSubject ($_maxTimeSpent min)',
                                Icons.star,
                              ),
                              _buildStatItem(
                                'Average session length',
                                _allSessions.isEmpty
                                    ? '0'
                                    : '${(_totalStudyTime / _allSessions.length).round()} minutes',
                                Icons.schedule,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Day of Week Stats
                      Text(
                        'Study Time by Day of Week',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      if (_dayOfWeekStats.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('No day of week data available'),
                          ),
                        )
                      else
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                ...[
                                  'Monday',
                                  'Tuesday',
                                  'Wednesday',
                                  'Thursday',
                                  'Friday',
                                  'Saturday',
                                  'Sunday',
                                ].map((day) {
                                  final minutes = _dayOfWeekStats[day] ?? 0;
                                  final maxMinutes =
                                      _dayOfWeekStats.values.isEmpty
                                          ? 1
                                          : _dayOfWeekStats.values.reduce(
                                            (a, b) => a > b ? a : b,
                                          );
                                  final progress =
                                      maxMinutes > 0
                                          ? minutes / maxMinutes
                                          : 0.0;

                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 12.0,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              day,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              '$minutes min',
                                              style: TextStyle(
                                                color: Colors.grey[700],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        LinearProgressIndicator(
                                          value: progress,
                                          minHeight: 8,
                                          backgroundColor: Colors.grey[200],
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                _getColorForDay(day),
                                              ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Subject breakdown
                      Text(
                        'Time by Subject',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      if (_subjectTotals.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('No study data available'),
                          ),
                        )
                      else
                        ..._subjectTotals.entries.map(
                          (entry) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          entry.key,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${entry.value} minutes',
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: entry.value / _totalStudyTime,
                                    minHeight: 8,
                                    backgroundColor: Colors.blue[100],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${(entry.value / _totalStudyTime * 100).toStringAsFixed(1)}% of total time',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Recent Sessions
                      Text(
                        'Recent Sessions',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      if (_allSessions.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('No recent sessions available'),
                          ),
                        )
                      else
                        ..._allSessions
                            .take(5)
                            .map(
                              (session) => Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).primaryColor.withOpacity(0.2),
                                    child: Text(
                                      session.subject.isNotEmpty
                                          ? session.subject[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ),
                                  title: Text(session.subject),
                                  subtitle: Row(
                                    children: [
                                      Icon(
                                        Icons.timer,
                                        size: 14,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text('${session.duration} minutes · '),
                                      Text(
                                        DateFormat(
                                          'MMM dd, yyyy',
                                        ).format(session.createdAt),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Color _getColorForDay(String day) {
    switch (day) {
      case 'Monday':
        return Colors.blue;
      case 'Tuesday':
        return Colors.green;
      case 'Wednesday':
        return Colors.orange;
      case 'Thursday':
        return Colors.purple;
      case 'Friday':
        return Colors.red;
      case 'Saturday':
        return Colors.teal;
      case 'Sunday':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }
}
