import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mtim/Trener/team_info_page.dart';
import 'package:mtim/Trener/trainings_page.dart';

class TimPage extends StatefulWidget {
  const TimPage({super.key});

  @override
  State<TimPage> createState() => _TimPageState();
}

class _TimPageState extends State<TimPage> {
  String? userTim;
  String? firstName;
  String? lastName;
  bool isLoading = true;
  List<String> trenersList = [];

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
            if (userData['Uloga'] == 'Trener') {
              setState(() {
                userTim = userData['Tim'];
              });
              QuerySnapshot teamDocs = await FirebaseFirestore.instance
                  .collection('Tim')
                  .where('Naziv', isEqualTo: userTim)
                  .get();
              for (var doc in teamDocs.docs) {
                var data = doc.data() as Map<String, dynamic>?;
                if (data != null && data.containsKey('Treners')) {
                  List<dynamic> treners = data['Treners'];
                  trenersList = treners.cast<String>();
                }
              }
              print(trenersList);
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching user Tim: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchUserTim();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return DefaultTabController(
        length: 2,
        child: Scaffold(
          body: Column(
            children: [
              Center(
                child: Container(
                  width: screenWidth * 0.9,
                  height: screenHeight * 0.2,
                  margin: const EdgeInsets.symmetric(horizontal: 0.0),
                  padding: const EdgeInsets.all(8.0),
                  child: Card(
                    color: Colors.purple[100],
                    margin: const EdgeInsets.symmetric(horizontal: 0.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '$userTim',
                            style: const TextStyle(fontSize: 25),
                          ),
                          for (var trener in trenersList)
                            Text(
                              trener,
                              style: const TextStyle(
                                  fontSize: 15, color: Colors.black87),
                            )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'Podatci'),
                  Tab(
                    text: 'Treninzi',
                  )
                ],
                indicatorColor: Colors.purple,
              ),
              const Expanded(
                child: TabBarView(children: [TeamInfoPage(), TrainingsPage()]),
              )
            ],
          ),
        ));
  }
}
