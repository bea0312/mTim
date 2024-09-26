import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mtim/firebase_api.dart';

class MemberClanarinaPage extends StatefulWidget {
  final Function(bool) onOverdueStatusChanged;
  const MemberClanarinaPage({
    super.key,
    required this.onOverdueStatusChanged,
  });

  @override
  State<MemberClanarinaPage> createState() => _MemberClanarinaPageState();
}

class _MemberClanarinaPageState extends State<MemberClanarinaPage> {
  List<Map<String, dynamic>> clanarinas = [];
  bool hasOverduePayment = false;
  Map<String, dynamic>? memberData;
  User? user = FirebaseAuth.instance.currentUser;
  String? userId;
  bool hasOverduePayments = false;
  StreamSubscription? _clanarinaSubscription;

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

        _listenForClanarinaUpdates();
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

  void _listenForClanarinaUpdates() {
    if (userId == null) return;

    _clanarinaSubscription = FirebaseFirestore.instance
        .collection('Clanica_Clanarina')
        .where('ClanicaUID', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isEmpty) {
        print('No documents found for ClanicaUID: ${userId}');
        return;
      }

      List<Map<String, dynamic>> clanarinasData = [];
      bool overdueFound = false;

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        var clanarinaId = data['ClanarinaUID'];

        DocumentSnapshot clanarinaSnapshot = await FirebaseFirestore.instance
            .collection('Clanarina')
            .doc(clanarinaId)
            .get();

        if (!clanarinaSnapshot.exists) {
          print('No Clanarina document found with ID: $clanarinaId');
          continue;
        }

        var clanarinaData = clanarinaSnapshot.data() as Map<String, dynamic>;

        bool isOverdue = _checkIfOverdue(
          clanarinaData['Razdoblje'],
          data['Status'],
        );

        if (isOverdue) {
          FirebaseApi().initMembershipNotification(clanarinaData['Razdoblje']);
          overdueFound = true;
          print(
              'Overdue payment detected for clanarina period: ${clanarinaData['Razdoblje']}');
        }

        clanarinasData.add({
          'Razdoblje': clanarinaData['Razdoblje'],
          'Cijena': data['Cijena'],
          'Status': data['Status'],
          'IsOverdue': isOverdue,
        });
      }

      setState(() {
        clanarinas = clanarinasData;
        hasOverduePayment = overdueFound;

        widget.onOverdueStatusChanged(overdueFound);
      });
    });
  }

  bool _checkIfOverdue(String razdoblje, String status) {
    if (status == 'Plaćeno') return false;

    DateTime now = DateTime.now();
    DateFormat dateFormat = DateFormat('MM/yyyy');
    DateTime clanarinaDate = dateFormat.parse(razdoblje);

    DateTime deadline =
        DateTime(clanarinaDate.year, clanarinaDate.month + 1, 15);

    return now.isAfter(deadline);
  }

  @override
  void dispose() {
    _clanarinaSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: clanarinas.isEmpty
          ? const Center(child: Text('No clanarinas found'))
          : ListView.builder(
              itemCount: clanarinas.length,
              itemBuilder: (context, index) {
                var clanarina = clanarinas[index];

                return Card(
                  color: clanarina['IsOverdue']
                      ? Colors.red[100]
                      : Colors.purple[100],
                  child: ListTile(
                    title: Text(
                      ' ${clanarina['Razdoblje']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cijena: ${clanarina['Cijena']}€'),
                        Text('Status: ${clanarina['Status']}'),
                      ],
                    ),
                    trailing: clanarina['Status'] == 'Plaćeno'
                        ? const Icon(Icons.check_box_outlined)
                        : const Icon(Icons.check_box_outline_blank),
                  ),
                );
              },
            ),
    );
  }
}
