import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../constants/app_colors.dart';
import '../constants/text_styles.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onCompleted;

  const OnboardingScreen({Key? key, required this.onCompleted }) : super(key: key);

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isCompleting = false;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      icon: Icons.handyman_outlined,
      title: 'Welcome to ServiGo',
      description: 'Your trusted partner for all home services. Find, book, and fix with just a few taps.',
      color: AppColors.trustBlue,
      gradient: AppColors.primaryGradient,
    ),
    OnboardingPage(
      icon: Icons.location_on_outlined,
      title: 'Find Local Experts',
      description: 'Discover verified service providers near you. Quality professionals at your doorstep.',
      color: AppColors.vividAzure,
      gradient: LinearGradient(
        colors: [AppColors.vividAzure, AppColors.modernTeal],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    OnboardingPage(
      icon: Icons.calendar_today_outlined,
      title: 'Easy Booking Process',
      description: 'Schedule services in minutes. Choose date, time, and get instant confirmation.',
      color: AppColors.actionOrange,
      gradient: AppColors.accentGradient,
    ),
    OnboardingPage(
      icon: Icons.notifications_active_outlined,
      title: 'Smart Reminders',
      description: 'Never miss an appointment. Get timely notifications and updates about your bookings.',
      color: AppColors.modernTeal,
      gradient: LinearGradient(
        colors: [AppColors.modernTeal, Color(0xFF00A8A8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Animated background gradient
          AnimatedContainer(
            duration: Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _pages[_currentPage].color.withOpacity(0.05),
                  AppColors.background,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          
          // PageView for onboarding slides
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              return _buildPage(_pages[index]);
            },
          ),
          
          // Top Skip button
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            right: 20,
            child: _currentPage < _pages.length - 1
                ? TextButton(
                    onPressed: _completeOnboarding,
                    child: Text(
                      'Skip',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : SizedBox(),
          ),
          
          // Bottom controls
          Positioned(
            bottom: 60,
            left: 20,
            right: 20,
            child: Column(
              children: [
                // Page indicator
                SmoothPageIndicator(
                  controller: _pageController,
                  count: _pages.length,
                  effect: ExpandingDotsEffect(
                    activeDotColor: _pages[_currentPage].color,
                    dotColor: AppColors.border,
                    dotHeight: 8,
                    dotWidth: 8,
                    spacing: 8,
                    expansionFactor: 3,
                  ),
                ),
                SizedBox(height: 40),
                
                // Next/Get Started button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isCompleting ? null : () {
                      if (_currentPage < _pages.length - 1) {
                        _pageController.nextPage(
                          duration: Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _completeOnboarding();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _pages[_currentPage].color,
                      padding: EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 3,
                      shadowColor: _pages[_currentPage].color.withOpacity(0.3),
                    ),
                    child: _isCompleting 
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _currentPage < _pages.length - 1 ? 'Continue' : 'Get Started',
                          style: AppTextStyles.buttonLarge.copyWith(
                            fontSize: 18,
                          ),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon/Image Container
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              gradient: page.gradient,
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(
                  color: page.color.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              page.icon,
              size: 80,
              color: Colors.white,
            ),
          ),
          
          SizedBox(height: 60),
          
          // Title with gradient text effect
          ShaderMask(
            shaderCallback: (bounds) {
              return page.gradient.createShader(bounds);
            },
            child: Text(
              page.title,
              textAlign: TextAlign.center,
              style: AppTextStyles.heading2.copyWith(
                color: Colors.white, // This gets overridden by the shader
                height: 1.2,
              ),
            ),
          ),
          
          SizedBox(height: 24),
          
          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              page.description,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _completeOnboarding() async {
    // Prevent multiple taps
    if (_isCompleting) return;
    
    setState(() {
      _isCompleting = true;
    });
    
    try {
      // Mark onboarding as completed
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);
      print('✅ Onboarding completed flag saved');
      
      // Navigate directly without using the callback
      if (mounted) {
        await Future.delayed(Duration(milliseconds: 300));
        
        // Option 1: Use Navigator directly
        Navigator.of(context).pushReplacementNamed('/language-selection');
        
        // Option 2: Call the callback if you still want to use it
        // widget.onCompleted();
      }
    } catch (e) {
      print('❌ Error completing onboarding: $e');
      setState(() {
        _isCompleting = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final Gradient gradient;

  OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.gradient,
  });
}