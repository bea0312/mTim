import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MemberOpremaPage extends StatefulWidget {
  const MemberOpremaPage({super.key});

  @override
  State<MemberOpremaPage> createState() => _MemberOpremaPageState();
}

class _MemberOpremaPageState extends State<MemberOpremaPage> {
  List<Map<String, dynamic>> things = [];
  String? opremaUID;
  Map<String, dynamic>? memberData;
  User? user = FirebaseAuth.instance.currentUser;
  String? userId;

  Future<void> _getMemberData() async {
    if (user == null) {
      print("User is not signed in.");
      return;
    }

    String? email = user?.email!;

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('Clanica')
          .where('Email', isEqualTo: email)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        DocumentSnapshot documentSnapshot = querySnapshot.docs.first;
        memberData = documentSnapshot.data() as Map<String, dynamic>;
        userId = documentSnapshot.id;
        print('User id: $userId');

        _getAllThingsForTheMember();
      } else {
        print("No member found with email $email");
      }
    } catch (e) {
      print("Error getting member by email: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _getMemberData();
  }

  Future<void> _getAllThingsForTheMember() async {
    try {
      QuerySnapshot clanicaOpremaSnapshot = await FirebaseFirestore.instance
          .collection('Clanica_Oprema')
          .where('ClanicaUID', isEqualTo: userId)
          .get();

      if (clanicaOpremaSnapshot.docs.isEmpty) {
        setState(() {
          things = [];
        });
        return;
      }

      List<Map<String, dynamic>> equipmentData = [];
      for (var doc in clanicaOpremaSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        var opremaId = data['OpremaUID'];
        opremaUID = opremaId;

        if (data['Vracanje'] != null) {
          continue;
        }

        DocumentSnapshot opremaSnapshot = await FirebaseFirestore.instance
            .collection('Oprema')
            .doc(opremaId)
            .get();

        if (!opremaSnapshot.exists) {
          continue;
        }

        var opremaData = opremaSnapshot.data() as Map<String, dynamic>;
        var naziv = opremaData['Naziv'] ?? 'Unknown';
        var velicina = opremaData['Veličina'] ?? 'Unknown';

        equipmentData.add({
          'Naziv': naziv,
          'Veličina': velicina,
          'Preuzimanje': data['Preuzimanje'] != null
              ? _formatDateOnly(data['Preuzimanje'])
              : 'N/A'
        });
      }

      setState(() {
        things = equipmentData;
      });
    } catch (e) {
      print('Error retrieving things: $e');
    }
  }

  String _formatDateOnly(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return DateFormat('dd.MM.yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: things.isEmpty
          ? Center(child: Text('No equipment found'))
          : ListView.builder(
              itemCount: things.length,
              itemBuilder: (context, index) {
                Map<String, dynamic> thing = things[index];
                print('Rendering ListTile for trening: $thing');
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                        color: Colors.purple[100],
                        borderRadius:
                            const BorderRadius.all(Radius.circular(15.0))),
                    child: ListTile(
                      title: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${thing['Naziv']}',
                              style: TextStyle(fontSize: 20),
                            ),
                            Text(
                              '${thing['Veličina']}',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
