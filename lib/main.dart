import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Parse().initialize(
    'knLR2uLkG8zhx2u07li5CNBabOI2QDK3r39IaWJi',
    'https://parseapi.back4app.com',
    clientKey: 'XtoVV3vykDozkgvxIQI8hHdKTHWHadKHy3h4EtZv',
    autoSendSessionId: true,
    debug: true,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: 'Study Session Tracker',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.themeData,
          home: const LoginScreen(),
        );
      },
    );
  }
}
