import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:mtim/Trener/clanarina_page.dart';
import 'package:mtim/Trener/dolasci_page.dart';
import 'package:mtim/Trener/home_page_content_trener.dart';
import 'package:mtim/Trener/oprema_page.dart';
import 'package:mtim/Trener/tim_page.dart';
import 'package:mtim/login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final user = FirebaseAuth.instance.currentUser!;
  String? username;
  int _selectedIndex = 0;

  final List<Widget> _widgetOptions = <Widget>[
    const HomePageContent(),
    const DolasciPage(),
    const OpremaPage(),
    const ClanarinaPage(),
    const TimPage()
  ];

  @override
  void initState() {
    super.initState();
    fetchUsername();
  }

  Future<void> fetchUsername() async {
    try {
      final uid = user.uid;
      final userDoc =
          await FirebaseFirestore.instance.collection('Clanica').doc(uid).get();
      if (userDoc.exists) {
        setState(() {
          username = userDoc['Email'];
        });
      }
    } catch (e) {
      print('Error fetching username: $e');
    }
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
          tabs: const [
            GButton(
              icon: Icons.group,
              text: 'Članice',
            ),
            GButton(
              icon: Icons.edit_calendar_outlined,
              text: 'Dolasci',
            ),
            GButton(
              icon: Icons.dry_cleaning_outlined,
              text: 'Oprema',
            ),
            GButton(
              icon: Icons.euro_symbol_rounded,
              text: 'Članarina',
            ),
            GButton(
              icon: Icons.person,
              text: 'Tim',
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
