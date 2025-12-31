import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/language_selection_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'firebase_options.dart'; // Make sure this file exists

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("✅ Firebase initialized successfully");
  } catch (e) {
    print("❌ Firebase initialization error: $e");
  }
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Home Service App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LanguageSelectionScreen(),
        '/login': (context) => LoginScreen(),
        '/main-home': (context) => HomeScreen(),  // Changed from '/home'
      },
      debugShowCheckedModeBanner: false,
    );
  }
}