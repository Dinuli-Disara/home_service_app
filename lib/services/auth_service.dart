import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Guest Login (Anonymous)
  Future<User?> guestLogin() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      final user = userCredential.user;
      
      if (user != null) {
        await _saveUserToPreferences(user);
        print('✅ Guest login successful: ${user.uid}');
      }
      
      return user;
    } catch (e) {
      print('❌ Guest login error: $e');
      return null;
    }
  }

  // Email Sign Up
  Future<User?> signUpWithEmail(String email, String password, String name) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final user = userCredential.user;
      
      if (user != null) {
        // Update display name
        await user.updateDisplayName(name);
        
        await _saveUserToPreferences(user, email: email, name: name);
        print('✅ Email sign up successful: ${user.email}');
      }
      
      return user;
    } on FirebaseAuthException catch (e) {
      print('❌ Email sign up error: ${e.code} - ${e.message}');
      throw e;
    } catch (e) {
      print('❌ Email sign up error: $e');
      throw e;
    }
  }

  // Email Login
  Future<User?> loginWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final user = userCredential.user;
      
      if (user != null) {
        await _saveUserToPreferences(user, email: email);
        print('✅ Email login successful: ${user.email}');
      }
      
      return user;
    } on FirebaseAuthException catch (e) {
      print('❌ Email login error: ${e.code} - ${e.message}');
      throw e;
    } catch (e) {
      print('❌ Email login error: $e');
      throw e;
    }
  }

  // Phone Login - Step 1: Send verification code
  Future<void> sendPhoneVerificationCode(String phoneNumber) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto sign-in if verification completes automatically
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          print('❌ Phone verification failed: ${e.message}');
          throw e;
        },
        codeSent: (String verificationId, int? resendToken) {
          // Save verification ID for later use
          _saveVerificationId(verificationId);
          print('✅ Verification code sent to $phoneNumber');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print('⚠️ Code auto retrieval timeout');
        },
        timeout: Duration(seconds: 60),
      );
    } catch (e) {
      print('❌ Error sending verification code: $e');
      throw e;
    }
  }

  // Phone Login - Step 2: Verify code
  Future<User?> verifyPhoneCode(String smsCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final verificationId = prefs.getString('phone_verification_id');
      
      if (verificationId == null) {
        throw Exception('No verification ID found');
      }
      
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      
      if (user != null) {
        await _saveUserToPreferences(user, phone: user.phoneNumber);
        print('✅ Phone login successful: ${user.phoneNumber}');
      }
      
      return user;
    } catch (e) {
      print('❌ Phone verification error: $e');
      throw e;
    }
  }

  // Google Sign In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the sign-in flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('❌ Google sign-in cancelled');
        return null;
      }
      
      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;
      
      // Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      
      if (user != null) {
        await _saveUserToPreferences(
          user, 
          email: user.email, 
          name: user.displayName,
        );
        print('✅ Google login successful: ${user.email}');
      }
      
      return userCredential;
    } catch (e) {
      print('❌ Google login error: $e');
      throw e;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userId');
      await prefs.remove('userEmail');
      await prefs.remove('userName');
      await prefs.remove('isGuest');
      
      print('✅ Logout successful');
    } catch (e) {
      print('❌ Logout error: $e');
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final user = _auth.currentUser;
    if (user != null) {
      return true;
    }
    
    // Check shared preferences as fallback
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId') != null;
  }

  // Helper: Save user to shared preferences
  Future<void> _saveUserToPreferences(
    User user, {
    String? email,
    String? name,
    String? phone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString('userId', user.uid);
    await prefs.setBool('isGuest', user.isAnonymous);
    
    if (email != null) {
      await prefs.setString('userEmail', email);
    }
    
    if (name != null) {
      await prefs.setString('userName', name);
    } else if (user.displayName != null) {
      await prefs.setString('userName', user.displayName!);
    } else {
      await prefs.setString('userName', 'User');
    }
    
    if (phone != null) {
      await prefs.setString('userPhone', phone);
    }
    
    await prefs.setString('loginMethod', user.isAnonymous ? 'guest' : 'authenticated');
  }

  // Helper: Save verification ID
  Future<void> _saveVerificationId(String verificationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('phone_verification_id', verificationId);
  }

  // Get user info from preferences
  Future<Map<String, dynamic>> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    
    return {
      'userId': prefs.getString('userId') ?? '',
      'userEmail': prefs.getString('userEmail') ?? '',
      'userName': prefs.getString('userName') ?? 'Guest',
      'userPhone': prefs.getString('userPhone') ?? '',
      'isGuest': prefs.getBool('isGuest') ?? true,
      'loginMethod': prefs.getString('loginMethod') ?? 'guest',
    };
  }

  // Update user profile
  Future<void> updateProfile({String? name, String? phone}) async {
    try {
      final user = _auth.currentUser;
      
      if (user != null) {
        if (name != null && name.isNotEmpty) {
          await user.updateDisplayName(name);
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userName', name);
        }
        
        print('✅ Profile updated successfully');
      }
    } catch (e) {
      print('❌ Error updating profile: $e');
      throw e;
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      print('✅ Password reset email sent to $email');
    } catch (e) {
      print('❌ Error sending password reset email: $e');
      throw e;
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      
      if (user != null) {
        await user.delete();
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        
        print('✅ Account deleted successfully');
      }
    } catch (e) {
      print('❌ Error deleting account: $e');
      throw e;
    }
  }
}