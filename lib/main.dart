import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:home_service_app/screens/customer_profile_screen.dart';
import 'package:home_service_app/screens/email_login_screen.dart';
import 'package:home_service_app/screens/my_bookings_screen.dart';
import 'package:home_service_app/screens/notification_screen.dart';
import 'package:home_service_app/screens/signup_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/language_selection_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/provider_profile_screen.dart';
import 'screens/provider_dashboard_screen.dart';
import 'screens/provider_registration_screen.dart';
import 'screens/phone_signup_screen.dart';
import 'firebase_options.dart';
import 'screens/map_screen.dart';
import 'screens/provider_list_screen.dart';
import 'screens/booking_screen.dart';
import 'screens/email_login_screen.dart';
import 'providers/language_provider.dart';
import 'services/reminder_service.dart';
import 'constants/theme.dart';
import 'constants/app_colors.dart';
import 'constants/text_styles.dart';
import 'screens/test_add_provider.dart';
import 'screens/view_provider_profile_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/provider_booking_screen.dart';

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
  String? _initialRoute;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }
  
  Future<void> _initializeApp() async {
    await Future.delayed(Duration(seconds: 2));

    try {
      final route = await _determineInitialRoute();
      if (mounted) {
        setState(() {
          _initialRoute = route;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error initializing app: $e');
      if (mounted) {
        setState(() {
          _initialRoute = '/login';
          _isLoading = false;
        });
      }
    }
  }
  
  Future<String> _determineInitialRoute() async {
    final prefs = await SharedPreferences.getInstance();
    
    bool onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
    bool languageSelected = prefs.getBool('language_selected') ?? false;
    bool loginCompleted = prefs.getBool('login_completed') ?? false;
    String userType = prefs.getString('userType') ?? '';
    String userId = prefs.getString('userId') ?? '';
    bool isGuest = prefs.getBool('isGuest') ?? false;
    
    print('📱 App Status Check:');
    print('   • Onboarding completed: $onboardingCompleted');
    print('   • Language selected: $languageSelected');
    print('   • Login completed: $loginCompleted');
    print('   • User ID: ${userId.isNotEmpty ? "Present" : "Missing"}');
    print('   • User Type: $userType');
    print('   • Is Guest: $isGuest');
    
    String route;
    
    if (!onboardingCompleted) {
      route = '/onboarding';
    } else if (!languageSelected) {
      route = '/language-selection';
    } else if (!loginCompleted || userId.isEmpty) {
      route = '/login';
    } else if (userType == 'provider') {
      route = '/provider-dashboard';
    } else if (userType == 'customer' || isGuest) {
      route = '/main-home';
    } else {
      route = '/login';
    }
    
    print('📱 Determined initial route: $route');
    
    // Initialize reminders if user is logged in
    if (userId.isNotEmpty) {
      try {
        final reminderService = ReminderService();
        await reminderService.initialize(userId);
        print('✅ Reminders initialized for user: $userId');
      } catch (e) {
        print('❌ Error initializing reminders: $e');
      }
    }
    
    return route;
  }
  
  @override
  Widget build(BuildContext context) {
    // Use Builder to separate the language provider logic
    return Builder(
      builder: (context) {
        final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
        
        // Load language on startup - only once
        WidgetsBinding.instance.addPostFrameCallback((_) {
          languageProvider.loadLanguage();
        });

        return MaterialApp(
          title: 'ServiGo',
          theme: AppTheme.lightTheme,
          home: _isLoading 
            ? SplashScreen()
            : _buildInitialScreen(context, _initialRoute!),
          routes: {
            '/onboarding': (context) => OnboardingScreen(
              onCompleted: () async {
                print('🎯 Onboarding completed, navigating to language selection');
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('onboarding_completed', true);
                
                Navigator.of(context).pushReplacementNamed('/language-selection');
              },
            ),
            '/language-selection': (context) => LanguageSelectionScreen(
              onLanguageSelected: () async {
                print('🎯 Language selected, navigating to login');
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('language_selected', true);
                
                Navigator.of(context).pushReplacementNamed('/login');
              },
            ),
            '/login': (context) => LoginScreen(
              onLoginCompleted: () {
                print('🎯 Login completed');
                _navigateAfterLogin(context);
              },
            ),
            '/signup': (context) => SignUpScreen(),
            '/phone-signup': (context) => PhoneSignUpScreen(),
            '/email-login': (context) => EmailLoginScreen(),
            '/main-home': (context) => HomeScreen(),
            '/provider-dashboard': (context) => ProviderDashboardScreen(),
            '/provider-registration': (context) => ProviderRegistrationScreen(),
            '/provider-profile': (context) => ProviderProfileScreen(),
            '/customer-profile': (context) => CustomerProfileScreen(),
            '/notifications': (context) => NotificationsScreen(),
            '/map': (context) => MapScreen(
              serviceType: (ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?)?['serviceType'],
              serviceName: (ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?)?['serviceName'],
            ),
            '/my-bookings': (context) => MyBookingsScreen(),
            '/booking': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              return BookingScreen(provider: args as Map<String, dynamic>);
            },
            '/view-provider-profile': (context) {
              final args = ModalRoute.of(context)!.settings.arguments;
              
              // Handle both String and Map for backward compatibility
              if (args is String) {
                return ViewProviderProfileScreen(providerId: args);
              } else if (args is Map<String, dynamic>) {
                return ViewProviderProfileScreen(providerId: args['providerId']);
              } else {
                // Fallback or error handling
                return Scaffold(
                  body: Center(child: Text('Provider ID not found')),
                );
              }
            },
            
            '/messages': (context) => MessagesScreen(),
            '/provider-bookings': (context) => ProviderBookingsScreen(),
          },
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
  
  Widget _buildInitialScreen(BuildContext context, String route) {
    print('🎯 Building screen for route: $route');
    
    switch (route) {
      case '/onboarding':
        return OnboardingScreen(
          onCompleted: () async {
            print('🎯 Onboarding completed callback executed');
            Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => LanguageSelectionScreen(
                onLanguageSelected: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('language_selected', true);
                  Navigator.of(context).pushReplacementNamed('/login');
                },
              ),
            ),
          );
        },
      );
      case '/language-selection':
        return LanguageSelectionScreen(
          onLanguageSelected: () async {
            print('🎯 Language selected callback executed');
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('language_selected', true);
            
            Navigator.of(context).pushReplacementNamed('/login');
          },
        );
      case '/login':
        return LoginScreen(
          onLoginCompleted: () {
            print('🎯 Login completed callback executed');
            _navigateAfterLogin(context);
          },
        );
      case '/provider-dashboard':
        return ProviderDashboardScreen();
      case '/main-home':
        return HomeScreen();
      default:
        print('⚠️ Unknown route, defaulting to login');
        return LoginScreen(
          onLoginCompleted: () {
            _navigateAfterLogin(context);
          },
        );
    }
  }
  
  Future<void> _navigateAfterLogin(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('login_completed', true);
      
      // Check user type and navigate accordingly
      final userType = prefs.getString('userType') ?? '';
      final isGuest = prefs.getBool('isGuest') ?? false;
      
      print('🎯 Navigating after login: userType=$userType, isGuest=$isGuest');
      
      if (userType == 'provider') {
        Navigator.of(context).pushReplacementNamed('/provider-dashboard');
      } else if (userType == 'customer' || isGuest) {
        Navigator.of(context).pushReplacementNamed('/main-home');
      } else {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      print('❌ Error in navigateAfterLogin: $e');
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }
}