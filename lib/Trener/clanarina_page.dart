import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ClanarinaPage extends StatefulWidget {
  const ClanarinaPage({super.key});

  @override
  State<ClanarinaPage> createState() => _ClanarinaPageState();
}

class _ClanarinaPageState extends State<ClanarinaPage> {
  String? userTim;
  bool isLoading = true;
  late Future<List<Map<String, dynamic>>> periodsAndMembersFuture;

  @override
  void initState() {
    super.initState();
    fetchUserTim();
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
            if (userData['Uloga'] == 'Trener') {
              setState(() {
                userTim = userData['Tim'];
                periodsAndMembersFuture = _getAllPeriodsAndMembers();
              });
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

  Future<List<Map<String, dynamic>>> _getAllPeriods() async {
    try {
      QuerySnapshot clanarinasSnapshot = await FirebaseFirestore.instance
          .collection('Clanarina')
          .orderBy('Razdoblje', descending: true)
          .get();

      List<Map<String, dynamic>> periods = clanarinasSnapshot.docs.map((doc) {
        return {
          'ClanarinaUID': doc.id,
          'Razdoblje': doc['Razdoblje'],
        };
      }).toList();

      print('Fetched periods: $periods');

      return periods;
    } catch (e) {
      print('Error fetching periods: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getAllClanarinasForPeriod(
      String clanarinaUID) async {
    try {
      QuerySnapshot clanarinasSnapshot = await FirebaseFirestore.instance
          .collection('Clanica_Clanarina')
          .where('ClanarinaUID', isEqualTo: clanarinaUID)
          .get();

      List<Map<String, dynamic>> membersList = [];

      for (var clanarinaDoc in clanarinasSnapshot.docs) {
        String clanicaUID = clanarinaDoc['ClanicaUID'] ?? '';
        String status = clanarinaDoc['Status'] ?? 'U čekanju';

        print('Fetching member with ClanicaUID: $clanicaUID');

        DocumentSnapshot memberSnapshot = await FirebaseFirestore.instance
            .collection('Clanica')
            .doc(clanicaUID)
            .get();

        if (memberSnapshot.exists) {
          var memberData = memberSnapshot.data() as Map<String, dynamic>;
          String memberRole = memberData['Uloga'] ?? '';
          String memberTeam = memberData['Tim'] ?? '';

          if (memberTeam == userTim && memberRole != 'Trener') {
            membersList.add({
              'ClanicaUID': clanicaUID,
              'Ime': memberData['Ime'] ?? 'Unknown',
              'Prezime': memberData['Prezime'] ?? 'Unknown',
              'Uloga': memberData['Uloga'] ?? '',
              'Tim': userTim,
              'Status': status,
              'DocumentId': clanarinaDoc.id
            });
          } else {
            print('No member found for ClanicaUID: $clanicaUID');
          }
        }
      }

      print('Fetched members for ClanarinaUID $clanarinaUID: $membersList');

      return membersList;
    } catch (e) {
      print('Error fetching clanarinas for period: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getAllPeriodsAndMembers() async {
    try {
      List<Map<String, dynamic>> allPeriodsData = [];
      List<Map<String, dynamic>> periods = await _getAllPeriods();

      for (var period in periods) {
        String clanarinaUID = period['ClanarinaUID'];
        List<Map<String, dynamic>> members =
            await _getAllClanarinasForPeriod(clanarinaUID);

        allPeriodsData.add({
          'ClanarinaUID': clanarinaUID,
          'Razdoblje': period['Razdoblje'],
          'Members': members
        });

        print(
            'Period: ${period['Razdoblje']} - Fetched members: $members for ClanarinaUID: $clanarinaUID');
      }

      print('Final data: $allPeriodsData');

      return allPeriodsData;
    } catch (e) {
      print('Error fetching all periods and members: $e');
      return [];
    }
  }

  Future<void> _updateStatusAndDate(String docId, bool newValue) async {
    try {
      String newStatus = newValue ? 'Plaćeno' : 'U čekanju';
      Timestamp? newDatumPlacanja = newValue ? Timestamp.now() : null;

      await FirebaseFirestore.instance
          .collection('Clanica_Clanarina')
          .doc(docId)
          .update({
        'Status': newStatus,
        'DatumPlacanja': newDatumPlacanja,
      });

      print(
          'Updated Status to $newStatus with DatumPlacanja: $newDatumPlacanja');

      setState(() {
        periodsAndMembersFuture = _getAllPeriodsAndMembers();
      });
    } catch (e) {
      print('Error updating status and date: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: periodsAndMembersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error loading data: ${snapshot.error}')),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('No data available')),
          );
        }

        final clanarinasData = snapshot.data
            ?.where(
                (doc) => doc['Uloga'] != 'Trener' && doc['Status'] != 'Ispis')
            .toList();

        return DefaultTabController(
          length: clanarinasData!.length,
          child: Scaffold(
            appBar: AppBar(
              bottom: TabBar(
                isScrollable: true,
                tabs: [
                  for (var clanarinaData in clanarinasData)
                    Tab(text: clanarinaData['Razdoblje']),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                for (var clanarinaData in clanarinasData)
                  ListView(
                    children: [
                      for (var member in clanarinaData['Members'])
                        Card(
                          color: Colors.purple[100],
                          child: ListTile(
                            title:
                                Text('${member['Ime']} ${member['Prezime']}'),
                            trailing: Checkbox(
                              value: member['Status'] == 'Plaćeno',
                              onChanged: member['Status'] == 'Plaćeno'
                                  ? null
                                  : (bool? value) {
                                      if (value != null) {
                                        _updateStatusAndDate(
                                            member['DocumentId'], value);
                                      }
                                    },
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
