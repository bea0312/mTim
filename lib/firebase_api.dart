import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}

class FirebaseApi {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  String? userTim;
  bool isLoading = true;

  DateTime formatTimeOnly(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return date;
  }

  Future<void> initPushNotifications(String place, DateTime start) async {
    await fetchUserTim();
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("Notification clicked and app opened");
    });
    _sendTrainingNotification(place, start);
  }

  Future<void> initMembershipNotification(String? period) async {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("Notification clicked and app opened");
    });
    _sendMembershipOverdueNotification(period);
  }

  Future<void> fetchUserTim() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userEmail = user.email;
        if (userEmail != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('Clanica')
              .where('Email', isEqualTo: userEmail)
              .get();
          if (userDoc.docs.isNotEmpty) {
            final userData = userDoc.docs.first;
            userTim = userData['Tim'];
            print("Fetched userTim: $userTim");
          } else {
            print('No user document found');
          }
        } else {
          print('User email is null');
        }
      } else {
        print('User is null');
      }
    } catch (e) {
      print('Error fetching user Tim: $e');
    }
  }

  void _listenToFirestoreChanges(String mjesto, DateTime pocetak) {
    FirebaseFirestore.instance.collection('Tim_Trening').snapshots().listen(
      (QuerySnapshot snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            var trainingData = change.doc.data() as Map<String, dynamic>?;
            pocetak = (trainingData != null && trainingData['Početak'] != null
                ? formatTimeOnly(trainingData['Početak'])
                : null)!;
            mjesto = trainingData?['Mjesto'];
            String? tim = trainingData?['Tim'];
            if (pocetak != null &&
                mjesto != null &&
                tim != null &&
                userTim != null) {
              if (tim.trim().toLowerCase() == userTim!.trim().toLowerCase()) {
                _sendTrainingNotification(mjesto, pocetak);
              } else {
                print("The document's 'Tim' does not match the user's 'Tim'.");
              }
            } else {
              print(
                  "Error: Document fields are null or missing. Document ID: ${change.doc.id}");
            }
          }
        }
      },
    );
  }

  Future<void> _sendTrainingNotification(
      String mjesto, DateTime pocetak) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'training_channel',
      'Training Notifications',
      channelDescription: 'Notifications for new trainings',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    String start = DateFormat('dd.MM.yyyy HH:mm').format(pocetak);

    await flutterLocalNotificationsPlugin.show(
      0,
      'Danas trening!',
      'Vrijeme i mjesto održavanja: $start, $mjesto',
      platformChannelSpecifics,
    );
  }

  Future<void> _sendMembershipOverdueNotification(String? period) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'membership_channel',
      'Membership Overdue Notifications',
      channelDescription: 'Notifications for membership overdue',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      'Nepodmirena članarina!',
      'Postoji nepodmirena članarina za $period',
      platformChannelSpecifics,
    );
  }
}
