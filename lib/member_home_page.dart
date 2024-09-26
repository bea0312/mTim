import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:intl/intl.dart';
import 'package:mtim/member_clanarina_page.dart';
import 'package:mtim/member_dolasci_page.dart';
import 'package:mtim/member_home_page_content.dart';
import 'package:mtim/member_oprema_page.dart';
import 'package:mtim/login_page.dart';

class MemberHomePage extends StatefulWidget {
  const MemberHomePage({super.key});

  @override
  State<MemberHomePage> createState() => _MemberHomePageState();
}

class _MemberHomePageState extends State<MemberHomePage> {
  final user = FirebaseAuth.instance.currentUser!;
  int _selectedIndex = 0;
  String? userId;
  bool hasOverduePayments = false;
  Map<String, dynamic>? memberData;
  List<Widget> _widgetOptions = <Widget>[];
  StreamSubscription? _membershipSubscription;

  Future<void> _getMemberData() async {
    String? email = user.email!;

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

        _listenForMembershipChanges();
      } else {
        print("No member found with email $email");
      }
    } catch (e) {
      print("Error getting member by email: $e");
    }
  }

  void _listenForMembershipChanges() {
    if (userId == null) {
      print("User ID is null. Can't listen for membership changes.");
      return;
    }

    _membershipSubscription = FirebaseFirestore.instance
        .collection('Clanica_Clanarina')
        .where('ClanicaUID', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isEmpty) {
        setState(() {
          hasOverduePayments = false;
        });
        return;
      }

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
        bool isOverdue = _isOverdue(clanarinaData['Razdoblje'], data['Status']);
        if (isOverdue) {
          overdueFound = true;
        }
      }

      setState(() {
        hasOverduePayments = overdueFound;
      });
    });
  }

  bool _isOverdue(String razdoblje, String status) {
    if (status == 'Plaćeno') return false;

    DateTime lastDayOfMonth = DateFormat("MM/yyyy").parse(razdoblje);
    lastDayOfMonth = DateTime(lastDayOfMonth.year, lastDayOfMonth.month + 1, 0);
    DateTime dueDate = lastDayOfMonth.add(const Duration(days: 15));

    return DateTime.now().isAfter(dueDate);
  }

  @override
  void initState() {
    super.initState();
    _getMemberData();

    _widgetOptions = <Widget>[
      const MemberHomePageContent(),
      const MemberDolasciPage(),
      const MemberOpremaPage(),
      MemberClanarinaPage(onOverdueStatusChanged: _onOverdueStatusChanged)
    ];
  }

  @override
  void dispose() {
    _membershipSubscription?.cancel();
    super.dispose();
  }

  void _onOverdueStatusChanged(bool isOverdue) {
    setState(() {
      hasOverduePayments = isOverdue;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(157, 173, 24, 199),
        title: const Center(
          child: Text(
            "Svetojanske mažoretkinje",
            style: TextStyle(color: Colors.white),
          ),
        ),
        actions: [
          IconButton(
            color: Colors.white.withOpacity(0.3),
            onPressed: _signOut,
            icon: const Icon(
              Icons.logout_rounded,
              color: Colors.white,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(0.0),
        child: GNav(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          gap: 8,
          tabBackgroundColor: const Color.fromARGB(98, 173, 24, 199),
          activeColor: Colors.white,
          color: Colors.black,
          selectedIndex: _selectedIndex,
          onTabChange: _onItemTapped,
          tabs: [
            const GButton(
              icon: Icons.person,
              text: 'Ja',
            ),
            const GButton(
              icon: Icons.edit_calendar_outlined,
              text: 'Dolasci',
            ),
            const GButton(
              icon: Icons.dry_cleaning_outlined,
              text: 'Oprema',
            ),
            GButton(
              icon: Icons.euro_symbol_rounded,
              text: 'Članarina',
              leading: hasOverduePayments
                  ? const Icon(
                      Icons.warning,
                      color: Colors.red,
                      size: 22,
                    )
                  : null,
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
    );
  }
}
