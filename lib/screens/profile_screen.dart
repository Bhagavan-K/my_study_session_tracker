// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:provider/provider.dart';
import '../services/back4app_service.dart';
import '../theme_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = true;
  bool _isUpdating = false;
  String _errorMessage = '';
  ParseUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await ParseUser.currentUser() as ParseUser?;

      if (!mounted) return;

      if (user != null) {
        setState(() {
          _currentUser = user;
          _usernameController.text = user.username ?? '';
          _emailController.text = user.emailAddress ?? '';
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load user data';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Error loading profile: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUpdating = true;
      _errorMessage = '';
    });

    try {
      if (_currentUser != null) {
        final currentUsername = _currentUser!.username;
        final newUsername = _usernameController.text;

        // Only update username if it has changed
        if (currentUsername != newUsername) {
          _currentUser!.username = newUsername;
        }

        // Email is generally not updated directly
        // For security, usually a verification email is sent first

        final response = await _currentUser!.save();

        if (!mounted) return;

        if (response.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
        } else {
          setState(() {
            _errorMessage =
                response.error?.message ?? 'Failed to update profile';
          });
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Error updating profile: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        alignment: Alignment.center,
                        margin: const EdgeInsets.only(bottom: 24, top: 16),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.2),
                          child: Text(
                            _usernameController.text.isNotEmpty
                                ? _usernameController.text[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Account Information',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _usernameController,
                                decoration: const InputDecoration(
                                  labelText: 'Username',
                                  prefixIcon: Icon(Icons.person),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a username';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emailController,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.email),
                                  hintText: 'Email cannot be changed directly',
                                ),
                                enabled: false,
                              ),
                              if (_errorMessage.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16.0),
                                  child: Text(
                                    _errorMessage,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: _isUpdating ? null : _updateProfile,
                                child:
                                    _isUpdating
                                        ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : const Text('UPDATE PROFILE'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'App Settings',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              SwitchListTile(
                                title: const Text('Dark Mode'),
                                subtitle: Text(
                                  themeProvider.isDarkMode
                                      ? 'Dark theme enabled'
                                      : 'Light theme enabled',
                                ),
                                secondary: Icon(
                                  themeProvider.isDarkMode
                                      ? Icons.dark_mode
                                      : Icons.light_mode,
                                ),
                                value: themeProvider.isDarkMode,
                                onChanged: (_) {
                                  themeProvider.toggleTheme();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Security',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              ListTile(
                                leading: const Icon(Icons.lock_reset),
                                title: const Text('Change Password'),
                                subtitle: const Text(
                                  'Reset your password via email',
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                ),
                                onTap: () async {
                                  final email = _currentUser?.emailAddress;
                                  if (email != null) {
                                    final result =
                                        await Back4AppService.resetPassword(
                                          email,
                                        );
                                    if (!mounted) return;

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          result['success']
                                              ? 'Password reset email sent to $email'
                                              : (result['error'] ??
                                                  'Failed to send reset email'),
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
