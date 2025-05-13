// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/study_session.dart';
import '../services/back4app_service.dart';
import '../widgets/session_card.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'statistics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<StudySession> _sessions = [];
  List<StudySession> _filteredSessions = [];
  bool _isLoading = true;
  String _searchQuery = '';
  int _currentStreak = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _validateSessionAndLoadData();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _filterSessions();
      });
    });
  }

  void _filterSessions() {
    if (_searchQuery.isEmpty) {
      _filteredSessions = List.from(_sessions);
    } else {
      _filteredSessions =
          _sessions
              .where(
                (session) => session.subject.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
              )
              .toList();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _validateSessionAndLoadData() async {
    final isSessionValid = await Back4AppService.validateSession();

    if (!mounted) return;

    if (!isSessionValid) {
      // If Session is invalid, redirect to login
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      return;
    }

    // If Session is valid, load data
    _loadSessions();
    _loadStreak();
  }

  Future<void> _loadSessions() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final sessions = await Back4AppService.getStudySessions();

      if (!mounted) return; // Check if widget is still mounted

      setState(() {
        _sessions = sessions;
        _filterSessions();
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to load sessions')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadStreak() async {
    try {
      final streak = await Back4AppService.getCurrentStreak();

      if (!mounted) return;

      setState(() {
        _currentStreak = streak;
      });
    } catch (e) {
      // Silently handle errors - streak will remain at 0
    }
  }

  Future<void> _logout() async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('LOGOUT'),
              ),
            ],
          ),
    );

    // If user canceled, don't proceed
    if (shouldLogout != true) return;

    setState(() {
      _isLoading = true;
    });

    final success = await Back4AppService.logout();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to logout')));
    }
  }

  void _showAddSessionDialog() {
    final subjectController = TextEditingController();
    final durationController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // Store the current context to use after dialog closes
    final scaffoldContext = context;

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Add Study Session'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                        prefixIcon: Icon(Icons.book),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter subject name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: durationController,
                      decoration: const InputDecoration(
                        labelText: 'Duration (minutes)',
                        prefixIcon: Icon(Icons.timer),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter duration';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        prefixIcon: Icon(Icons.note),
                        hintText: 'Add any additional notes about your session',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final subject = subjectController.text;
                    final duration = int.parse(durationController.text);
                    final notes = notesController.text;
                    Navigator.pop(dialogContext);

                    final result = await Back4AppService.addStudySession(
                      subject,
                      duration,
                      notes: notes,
                    );

                    if (!mounted) return;

                    if (result['success']) {
                      _loadSessions();
                      _loadStreak(); // Refresh streak after adding a new session
                    } else {
                      // Check if session expired
                      if (result.containsKey('sessionExpired') &&
                          result['sessionExpired'] == true) {
                        // Redirect to login screen if session expired
                        Navigator.of(scaffoldContext).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      } else {
                        // Use the stored scaffoldContext instead of dialogContext
                        if (mounted) {
                          ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                result['error'] ?? 'Failed to add session',
                              ),
                            ),
                          );
                        }
                      }
                    }
                  }
                },
                child: const Text('ADD'),
              ),
            ],
          ),
    );
  }

  void _showEditSessionDialog(StudySession session) {
    final subjectController = TextEditingController(text: session.subject);
    final durationController = TextEditingController(
      text: session.duration.toString(),
    );
    final notesController = TextEditingController(text: session.notes);
    final formKey = GlobalKey<FormState>();

    // Store the current context to use after dialog closes
    final scaffoldContext = context;

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Edit Study Session'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                        prefixIcon: Icon(Icons.book),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter subject name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: durationController,
                      decoration: const InputDecoration(
                        labelText: 'Duration (minutes)',
                        prefixIcon: Icon(Icons.timer),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter duration';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        prefixIcon: Icon(Icons.note),
                        hintText: 'Add any additional notes about your session',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final subject = subjectController.text;
                    final duration = int.parse(durationController.text);
                    final notes = notesController.text;
                    Navigator.pop(dialogContext);

                    final result = await Back4AppService.updateStudySession(
                      session,
                      subject,
                      duration,
                      notes: notes,
                    );

                    if (!mounted) return;

                    if (result['success']) {
                      _loadSessions();
                    } else {
                      // Check if session expired
                      if (result.containsKey('sessionExpired') &&
                          result['sessionExpired'] == true) {
                        // Redirect to login screen if session expired
                        Navigator.of(scaffoldContext).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      } else {
                        // Use the stored scaffoldContext
                        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              result['error'] ?? 'Failed to update session',
                            ),
                          ),
                        );
                      }
                    }
                  }
                },
                child: const Text('UPDATE'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteSession(StudySession session) async {
    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Delete'),
            content: Text(
              'Are you sure you want to delete the session "${session.subject}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('DELETE'),
              ),
            ],
          ),
    );

    // If user canceled, don't proceed
    if (shouldDelete != true) return;

    final result = await Back4AppService.deleteStudySession(session);

    if (!mounted) return;

    if (result['success']) {
      _loadSessions();
      _loadStreak(); // Refresh streak after deleting a session

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session deleted successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      // Check if session expired
      if (result.containsKey('sessionExpired') &&
          result['sessionExpired'] == true) {
        // Redirect to login screen if session expired
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to delete session'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Sessions'),
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          // Streak banner
          if (_currentStreak > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 16.0,
              ),
              color: Theme.of(context).primaryColor,
              child: Row(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    color: Colors.orangeAccent,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$_currentStreak day${_currentStreak > 1 ? 's' : ''} streak!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StatisticsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.bar_chart, color: Colors.white),
                    label: const Text(
                      'View Stats',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by subject...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          // Session list
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredSessions.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isEmpty
                                ? Icons.book
                                : Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No study sessions yet.\nTap + to add a new session.'
                                : 'No sessions found for "$_searchQuery"',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                          if (_searchQuery.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                _searchController.clear();
                              },
                              child: const Text('CLEAR SEARCH'),
                            ),
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _loadSessions,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _filteredSessions.length,
                        itemBuilder: (context, index) {
                          final session = _filteredSessions[index];
                          return SessionCard(
                            session: session,
                            onEdit: () => _showEditSessionDialog(session),
                            onDelete: () => _deleteSession(session),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add Session',
        onPressed: _showAddSessionDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
