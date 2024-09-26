import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mtim/change_password_dialog.dart';

class MemberHomePageContent extends StatefulWidget {
  const MemberHomePageContent({super.key});

  @override
  State<MemberHomePageContent> createState() => _MemberHomePageContentState();
}

class _MemberHomePageContentState extends State<MemberHomePageContent> {
  Map<String, dynamic>? memberData;
  User? user = FirebaseAuth.instance.currentUser;
  String? userId;
  TextEditingController adresaController = TextEditingController();
  TextEditingController mobClaniceController = TextEditingController();
  TextEditingController mobRodController = TextEditingController();

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

        setState(() {
          adresaController.text = memberData?['Adresa'] ?? '';
          mobClaniceController.text =
              memberData?['Broj mobitela članice'] ?? '';
          mobRodController.text = memberData?['Broj mobitela roditelja'] ?? '';
        });
      } else {
        print("No member found with email $email");
      }
    } catch (e) {
      print("Error getting member by email: $e");
    }
  }

  Future<void> updateMemberData() async {
    final updatedMember = {
      'Adresa': adresaController.text,
      'Broj mobitelja roditelja': mobRodController.text,
      'Broj mobitela članice': mobClaniceController.text,
    };

    FirebaseFirestore.instance
        .collection('Clanica')
        .doc(userId)
        .update(updatedMember);
  }

  @override
  void initState() {
    super.initState();
    _getMemberData();
  }

  @override
  void dispose() {
    adresaController.dispose();
    mobClaniceController.dispose();
    mobRodController.dispose();
    super.dispose();
  }

  Future<void> _openChangePasswordDialog(BuildContext context) async {
    print('Open dialog pressed');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ChangePasswordDialog();
      },
    );
  }

  Widget CustomTextField(TextEditingController controller, String? label) {
    return Padding(
      padding: const EdgeInsets.only(left: 0, right: 16, top: 8.0, bottom: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.normal, color: Colors.black),
          border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(15)),
              borderSide: BorderSide(color: Colors.purple)),
          contentPadding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
        ),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        onEditingComplete: () {
          updateMemberData();
          FocusScope.of(context).unfocus();
        },
        autofocus: false,
      ),
    );
  }

  Widget CustomDivider() {
    return const Divider(
      color: Colors.purple,
      thickness: 2,
      indent: 0,
      endIndent: 16,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Center(
              child: Container(
                width: screenWidth * 0.9,
                height: screenHeight * 0.18,
                margin: const EdgeInsets.symmetric(horizontal: 0.0),
                padding:
                    const EdgeInsets.only(top: 8.0, left: 10.0, right: 10.0),
                child: Card(
                  color: Colors.purple[100],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 10.0, left: 10),
                        child: SizedBox(
                          width: 100,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Ime',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.normal),
                                    ),
                                    Text(
                                      '${memberData?['Ime'] ?? ''}',
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(
                                  height: 20,
                                ),
                                const Text(
                                  'Prezime',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                                Text(
                                  '${memberData?['Prezime'] ?? ''}',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold),
                                ),
                              ]),
                        ),
                      ),
                      const VerticalDivider(
                        color: Colors.purple,
                        thickness: 2,
                        width: 20,
                        indent: 15,
                        endIndent: 15,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0, top: 10),
                        child: SizedBox(
                          width: 100,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Datum rođenja',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.normal),
                                    ),
                                    Text(
                                      '${memberData?['Datum rođenja'] ?? ''}',
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(
                                  height: 20,
                                ),
                                const Text(
                                  'OIB',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                                Text(
                                  '${memberData?['OIB'] ?? ''}',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold),
                                ),
                              ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Container(
                width: screenWidth * 0.9,
                height: screenHeight * 0.65,
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                padding: const EdgeInsets.all(8.0),
                child: SingleChildScrollView(
                  child: Card(
                    color: Colors.purple[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  memberData?['Tim'] ?? '',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                )
                              ],
                            ),
                          ),
                          Column(
                            children: [CustomDivider()],
                          ),
                          Column(
                            children: [
                              CustomTextField(adresaController, 'Adresa')
                            ],
                          ),
                          Column(
                            children: [
                              CustomTextField(
                                  mobClaniceController, 'Broj mobitela članice')
                            ],
                          ),
                          Column(
                            children: [
                              CustomTextField(
                                  mobRodController, 'Broj mobitela roditelja')
                            ],
                          ),
                          CustomDivider(),
                          const Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: const Column(
                              children: [
                                Text('Email', style: TextStyle(fontSize: 13))
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Column(
                              children: [
                                Text(
                                  '${memberData?['Email'] ?? ''}',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const Column(
                            children: [
                              Text('Članica od', style: TextStyle(fontSize: 13))
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                '${memberData?['Članica od'] ?? ''}',
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Column(
                              children: [
                                Text(
                                  'Sljedeća preregistracija',
                                  style: TextStyle(fontSize: 13),
                                )
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Column(
                              children: [
                                Text(
                                  '${memberData?['Godina preregistracije'] ?? ''}',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [CustomDivider()],
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          Column(
                            children: [
                              Center(
                                child: GestureDetector(
                                  onTap: () {
                                    _openChangePasswordDialog(context);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8.0),
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.all(
                                          Radius.circular(15.0)),
                                      color: Colors.white,
                                      border: Border.all(
                                          color: Colors.purple, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.5),
                                          spreadRadius: 5,
                                          blurRadius: 7,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.sync_lock,
                                          color: Colors.purple,
                                          size: 25,
                                        ),
                                        Text(
                                          'Promijeni lozinku',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
