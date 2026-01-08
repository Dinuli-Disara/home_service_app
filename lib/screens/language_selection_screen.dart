import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/language_provider.dart';
import '../constants/app_colors.dart';
import '../constants/text_styles.dart';
import '../widgets/servigo_logo.dart';

class LanguageSelectionScreen extends StatelessWidget {
  final VoidCallback? onLanguageSelected;
  const LanguageSelectionScreen({Key? key, this.onLanguageSelected,}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView( // ✅ ADDED: Allows scrolling if needed
          physics: BouncingScrollPhysics(), // ✅ Smooth scrolling
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start, // ✅ Changed from center
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Spacer (adjusts for different screen sizes)
                SizedBox(height: 40),
                
                // ServiGo Logo
                ServiGoLogo(size: 80, showTagline: true, showIcon: true),
                SizedBox(height: 40),
                
                // Language Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.trustBlue.withOpacity(0.2),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.language,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 30),
                
                // Title
                Text(
                  'Choose Your Language',
                  style: AppTextStyles.heading2.copyWith(
                    color: AppColors.trustBlue,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                
                // Subtitle
                Text(
                  'Select your preferred language for ServiGo',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 40),
                
                // English Button - Trust Blue
                _buildLanguageButton(
                  context: context,
                  text: 'English',
                  code: 'en',
                  color: AppColors.trustBlue,
                  languageProvider: languageProvider,
                ),
                SizedBox(height: 16),
                
                // Sinhala Button - Modern Teal
                _buildLanguageButton(
                  context: context,
                  text: 'සිංහල',
                  code: 'si',
                  color: AppColors.modernTeal,
                  languageProvider: languageProvider,
                ),
                SizedBox(height: 16),
                
                // Tamil Button - Vivid Azure
                _buildLanguageButton(
                  context: context,
                  text: 'தமிழ்',
                  code: 'ta',
                  color: AppColors.vividAzure,
                  languageProvider: languageProvider,
                ),
                SizedBox(height: 30),
                
                // Skip for now (optional) - MOVE ABOVE BOTTOM SPACER
                TextButton(
                  onPressed: () async {
                    // Use English as default
                    languageProvider.setLanguage('en');

                    // Save language selection
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('selected_language', 'en');
                    await prefs.setBool('language_selected', true);

                     // Call the callback if provided
                    if (onLanguageSelected != null) {
                      onLanguageSelected!();
                    }
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: Text(
                    'Continue in English',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageButton({
    required BuildContext context,
    required String text,
    required String code,
    required Color color,
    required LanguageProvider languageProvider,
    VoidCallback? onLanguageSelected,
  }) {
    return ElevatedButton(
      onPressed: () async {
        // Animate button press
        await languageProvider.setLanguage(code);
        
        // Save language selection to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('selected_language', code);
        await prefs.setBool('language_selected', true);
        
        // Call the callback if provided
        if (onLanguageSelected != null) {
          onLanguageSelected!();
        }

        // Show brief loading/confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Language set to ${code == 'en' ? 'English' : code == 'si' ? 'Sinhala' : 'Tamil'}'),
            backgroundColor: color,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: Duration(milliseconds: 800),
          ),
        );
        
        // Navigate after a brief delay
        await Future.delayed(Duration(milliseconds: 900));
        Navigator.pushReplacementNamed(context, '/login');
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        minimumSize: Size(double.infinity, 60), 
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 3,
        shadowColor: color.withOpacity(0.3),
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      child: Text(
        text,
        style: AppTextStyles.buttonLarge.copyWith(
          fontSize: 18,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}