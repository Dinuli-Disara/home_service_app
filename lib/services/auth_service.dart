import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final UserService _userService = UserService();

  // ==================== AUTH METHODS ====================

  // Guest Login (Anonymous) - Always customer
  Future<User?> guestLogin() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      final user = userCredential.user;
      
      if (user != null) {
        await _saveUserToPreferences(user, userType: 'customer');
        
        // Save guest user to Firestore
        await _userService.saveCustomer(
          userId: user.uid,
          name: 'Guest User',
          isGuest: true,
          authMethod: 'guest',
        );
        
        print('✅ Guest login successful: ${user.uid}');
      }
      
      return user;
    } catch (e) {
      print('❌ Guest login error: $e');
      return null;
    }
  }

  // Email Sign Up with User Type
  Future<User?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String userType, // 'customer' or 'provider'
    String? phone,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final user = userCredential.user;
      
      if (user != null) {
        await user.updateDisplayName(name);
        
        await _saveUserToPreferences(
          user, 
          email: email, 
          name: name,
          phone: phone,
          userType: userType,
        );
        
        // Save to Firestore based on user type
        if (userType == 'customer') {
          await _userService.saveCustomer(
            userId: user.uid,
            name: name,
            email: email,
            phone: phone,
            authMethod: 'email',
          );
        } else if (userType == 'provider') {
          // Provider will complete registration later
          await _userService.saveServiceProvider(
            userId: user.uid,
            name: name,
            phone: phone ?? '',
            serviceType: 'general', // Default, will be updated
            email: email,
            // Note: authMethod parameter not in saveServiceProvider, so we'll store it in users collection
          );
          
          // Add auth method to users collection for provider
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'authMethod': 'email',
          });
        }
        
        print('✅ Email sign up successful: ${user.email} ($userType)');
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

  // Email Login with User Type Check
  Future<User?> loginWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final user = userCredential.user;
      
      if (user != null) {
        // Get user type from Firestore
        final userType = await _userService.getUserType(user.uid);
        final actualUserType = userType ?? 'customer';
        
        await _saveUserToPreferences(
          user, 
          email: email,
          userType: actualUserType,
        );
        
        // Check if user exists in Firestore, create if not
        final userExists = await _userService.checkUserExists(user.uid);
        if (!userExists) {
          await _userService.saveCustomer(
            userId: user.uid,
            name: user.displayName ?? 'User',
            email: user.email,
            authMethod: 'email',
          );
        } else {
          await _userService.updateLastActive(user.uid);
        }
        
        print('✅ Email login successful: ${user.email} ($actualUserType)');
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
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          print('❌ Phone verification failed: ${e.message}');
          throw e;
        },
        codeSent: (String verificationId, int? resendToken) {
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

  // Phone Login - Step 2: Verify code with User Type
  Future<User?> verifyPhoneCode({
    required String smsCode,
    required String name,
    required String userType,
  }) async {
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
        await _saveUserToPreferences(
          user, 
          phone: user.phoneNumber,
          name: name,
          userType: userType,
        );
        
        // Save to Firestore based on user type
        if (userType == 'customer') {
          await _userService.saveCustomer(
            userId: user.uid,
            name: name,
            phone: user.phoneNumber,
            authMethod: 'phone',
          );
        } else if (userType == 'provider') {
          await _userService.saveServiceProvider(
            userId: user.uid,
            name: name,
            phone: user.phoneNumber ?? '',
            serviceType: 'general',
            // Note: saveServiceProvider doesn't have authMethod parameter
          );
          
          // Add auth method to users collection for provider
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'authMethod': 'phone',
          });
        }
        
        print('✅ Phone login successful: ${user.phoneNumber} ($userType)');
      }
      
      return user;
    } catch (e) {
      print('❌ Phone verification error: $e');
      throw e;
    }
  }

  // Google Sign In with User Type
  Future<UserCredential?> signInWithGoogle({String? userType}) async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('❌ Google sign-in cancelled');
        return null;
      }
      
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;
      
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      
      if (user != null) {
        final actualUserType = userType ?? 'customer';
        
        await _saveUserToPreferences(
          user, 
          email: user.email, 
          name: user.displayName,
          userType: actualUserType,
        );
        
        // Check if user exists in Firestore
        final userExists = await _userService.checkUserExists(user.uid);
        if (!userExists) {
          if (actualUserType == 'customer') {
            await _userService.saveCustomer(
              userId: user.uid,
              name: user.displayName ?? 'User',
              email: user.email,
              profileImage: user.photoURL,
              authMethod: 'google',
            );
          } else if (actualUserType == 'provider') {
            await _userService.saveServiceProvider(
              userId: user.uid,
              name: user.displayName ?? 'User',
              phone: user.phoneNumber ?? '',
              serviceType: 'general',
              email: user.email,
              profileImage: user.photoURL,
            );
            
            // Add auth method to users collection for provider
            await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
              'authMethod': 'google',
            });
          }
        }
        
        print('✅ Google login successful: ${user.email} ($actualUserType)');
      }
      
      return userCredential;
    } catch (e) {
      print('❌ Google login error: $e');
      throw e;
    }
  }

  // ==================== USER MANAGEMENT ====================

  // Logout
  Future<void> logout() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
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
    
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId') != null;
  }

  // Get current user info
  Future<Map<String, dynamic>> getCurrentUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _auth.currentUser;
    
    return {
      'userId': user?.uid ?? prefs.getString('userId') ?? '',
      'userEmail': user?.email ?? prefs.getString('userEmail') ?? '',
      'userName': user?.displayName ?? prefs.getString('userName') ?? 'Guest',
      'userPhone': user?.phoneNumber ?? prefs.getString('userPhone') ?? '',
      'userType': prefs.getString('userType') ?? 'customer',
      'isGuest': prefs.getBool('isGuest') ?? true,
      'loginMethod': prefs.getString('loginMethod') ?? 'guest',
    };
  }

  // Get user type
  Future<String> getUserType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userType') ?? 'customer';
  }

  // Update user profile
  Future<void> updateProfile({String? name, String? email, String? phone}) async {
    try {
      final user = _auth.currentUser;
      
      if (user != null) {
        final updates = <String, dynamic>{};
        
        if (name != null && name.isNotEmpty) {
          await user.updateDisplayName(name);
          updates['name'] = name;
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userName', name);
        }
        
        await _userService.updateUserProfile(
            userId: user.uid,
            name: name,
            email: email,
            phone: phone,
          );
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
        await _userService.deleteUser(user.uid);
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

  // ==================== HELPER METHODS ====================

  // Save user to shared preferences with user type
  Future<void> _saveUserToPreferences(
    User user, {
    String? email,
    String? name,
    String? phone,
    String userType = 'customer',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString('userId', user.uid);
    await prefs.setBool('isGuest', user.isAnonymous);
    await prefs.setString('userType', userType);
    
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

  // Save verification ID
  Future<void> _saveVerificationId(String verificationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('phone_verification_id', verificationId);
  }

  // ==================== FIREBASE FIRESTORE METHODS ====================

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserDataFromFirestore() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        return await _userService.getUserData(user.uid);
      }
      return null;
    } catch (e) {
      print('❌ Error getting user data from Firestore: $e');
      return null;
    }
  }

  // Check if email exists
  Future<bool> checkEmailExists(String email) async {
    try {
      return await _userService.emailExists(email);
    } catch (e) {
      print('❌ Error checking email existence: $e');
      return false;
    }
  }

  // Check if phone exists
  Future<bool> checkPhoneExists(String phone) async {
    try {
      return await _userService.phoneExists(phone);
    } catch (e) {
      print('❌ Error checking phone existence: $e');
      return false;
    }
  }

  // Update user location
  Future<void> updateUserLocation({
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _userService.updateUserLocation(
          userId: user.uid,
          address: address,
          latitude: latitude,
          longitude: longitude,
        );
      }
    } catch (e) {
      print('❌ Error updating user location: $e');
      throw e;
    }
  }

  // Get current user
  User? get currentFirebaseUser => _auth.currentUser;
}