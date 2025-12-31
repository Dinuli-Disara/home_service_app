import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseTest {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Test if Firestore is connected
  Future<void> testConnection() async {
    try {
      print('🔄 Testing Firebase Firestore connection...');
      
      // Try to write a test document
      await _firestore.collection('test').doc('connection_test').set({
        'test': 'Hello Firebase',
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      print('✅ Firestore write successful!');
      
      // Try to read it back
      DocumentSnapshot doc = await _firestore
          .collection('test')
          .doc('connection_test')
          .get();
          
      if (doc.exists) {
        print('✅ Firestore read successful! Data: ${doc.data()}');
      }
      
    } catch (e) {
      print('❌ Firestore error: $e');
      print('Make sure:');
      print('1. Firestore database is created in Firebase Console');
      print('2. Firebase config files are properly added');
      print('3. Internet connection is available');
    }
  }

  // Clear test data
  Future<void> cleanupTest() async {
    try {
      await _firestore.collection('test').doc('connection_test').delete();
      print('✅ Test data cleaned up');
    } catch (e) {
      print('❌ Cleanup error: $e');
    }
  }
}