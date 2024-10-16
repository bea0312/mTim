import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> storeFCMToken() async {
  try {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user is logged in.');
      return;
    }
    String? email = user.email;
    if (email == null) {
      print('User email is null.');
      return;
    }
    String? token = await FirebaseMessaging.instance.getToken();
    print('FCM token: $token');
    if (token != null) {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('Clanica')
          .where('Email', isEqualTo: email)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        DocumentSnapshot userDoc = querySnapshot.docs.first;
        await userDoc.reference.update({'fcmToken': token});
        print('FCM token updated successfully in Firestore.');
      } else {
        print('No document found with email: $email');
      }
    } else {
      print('Failed to retrieve FCM token.');
    }
  } catch (e) {
    print('Error storing FCM token: $e');
  }
}
