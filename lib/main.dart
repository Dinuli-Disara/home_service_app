import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:home_service_app/screens/email_login_screen.dart';
import 'package:home_service_app/screens/my_bookings_screen.dart';
import 'package:home_service_app/screens/phone_login_screen.dart';
import 'package:home_service_app/screens/signup_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/language_selection_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/phone_signup_screen.dart';
import 'firebase_options.dart';
import 'screens/map_screen.dart';
import 'screens/provider_list_screen.dart';
import 'screens/provider_details_screen.dart';
import 'screens/booking_screen.dart';
import 'screens/email_login_screen.dart';
import 'screens/phone_login_screen.dart';
import 'providers/language_provider.dart';
import 'services/reminder_service.dart';
import 'constants/theme.dart';
import 'constants/app_colors.dart';
import 'constants/text_styles.dart';

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
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: ServiGoApp(),
    ),
  );
}

class ServiGoApp extends StatefulWidget {
  @override
  _ServiGoAppState createState() => _ServiGoAppState();
}

class _ServiGoAppState extends State<ServiGoApp> {
  bool _remindersInitialized = false;
  bool? _onboardingCompleted;
  
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _initializeReminders();
    await _checkOnboardingStatus();
  }
  
  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    bool completed = prefs.getBool('onboarding_completed') ?? false;
    
    print('📱 Onboarding status: $completed');
    
    if (mounted) {
      setState(() {
        _onboardingCompleted = completed;
      });
    }
  }
  
  Future<void> _initializeReminders() async {
    if (_remindersInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      
      if (userId != null && userId.isNotEmpty) {
        final reminderService = ReminderService();
        await reminderService.initialize(userId);
        print('✅ Reminders initialized for user: $userId');
      } else {
        print('ℹ️ No user logged in, skipping reminder initialization');
      }
      
      _remindersInitialized = true;
    } catch (e) {
      print('❌ Error initializing reminders: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        // Load language on startup
        WidgetsBinding.instance.addPostFrameCallback((_) {
          languageProvider.loadLanguage();
        });

        return MaterialApp(
          title: 'ServiGo', // Fixed title
          theme: AppTheme.lightTheme, // ✅ Use our custom theme
          home: _onboardingCompleted == null
              ? SplashScreen() // Still loading
              : _onboardingCompleted!
                  ? LanguageSelectionScreen() // Onboarding completed
                  : OnboardingScreen( // Show onboarding
                      onCompleted: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('onboarding_completed', true);
                        
                        if (mounted) {
                          setState(() {
                            _onboardingCompleted = true;
                          });
                        }
                      },
                    ),
          routes: {
            '/language-selection': (context) => LanguageSelectionScreen(),
            '/login': (context) => LoginScreen(),
            '/signup': (context) => SignUpScreen(),
            '/phone-signup': (context) => PhoneSignUpScreen(),
            '/phone-login': (context) => PhoneLoginScreen(),
            '/email-login': (context) => EmailLoginScreen(),
            '/main-home': (context) => HomeScreen(),
            '/map': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              return MapScreen(arguments: args as Map<String, dynamic>?);
            },
            '/provider-details': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              return ProviderDetailsScreen(provider: args as Map<String, dynamic>);
            },
            '/my-bookings': (context) => MyBookingsScreen(),
            '/booking': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              return BookingScreen(provider: args as Map<String, dynamic>);
            },
          },
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
