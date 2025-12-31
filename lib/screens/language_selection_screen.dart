import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({Key? key}) : super(key: key);

  Future<void> _saveLanguagePreference(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', languageCode);
    print('Language saved: $languageCode');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.language,
              size: 100,
              color: Colors.blue,
            ),
            SizedBox(height: 30),
            Text(
              'Choose Your Language',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 40),
            
            _buildLanguageButton(context, 'English', 'en', Colors.blue),
            SizedBox(height: 20),
            _buildLanguageButton(context, 'සිංහල', 'si', Colors.green),
            SizedBox(height: 20),
            _buildLanguageButton(context, 'தமிழ்', 'ta', Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageButton(BuildContext context, String text, String code, Color color) {
    return ElevatedButton(
      onPressed: () async {
        await _saveLanguagePreference(code);
        Navigator.pushReplacementNamed(context, '/login');
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        minimumSize: Size(250, 60),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 20, color: Colors.white),
      ),
    );
  }
}