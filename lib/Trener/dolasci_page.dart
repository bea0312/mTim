import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DolasciPage extends StatefulWidget {
  const DolasciPage({super.key});

  @override
  State<DolasciPage> createState() => _DolasciPageState();
}

class _DolasciPageState extends State<DolasciPage> {
  String? userTim;
  bool isLoading = true;
  Map<String, List<Map<String, dynamic>>> memberTrainings = {};
  TextEditingController searchController = TextEditingController();
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    searchController.addListener(_onSearchChanged);
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
              if (mounted) {
                setState(() {
                  userTim = userData['Tim'];
                });
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching user Tim: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Stream<List<Map<String, dynamic>>> getMemberTrainingsStream(String memberId) {
    return FirebaseFirestore.instance
        .collection('Clanica_Tim_Trening')
        .where('ClanicaUID', isEqualTo: memberId)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> treningsData = [];
      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        var timTreningId = data['Tim_TreningUID'];

        DocumentSnapshot timTreningSnapshot = await FirebaseFirestore.instance
            .collection('Tim_Trening')
            .doc(timTreningId)
            .get();

        if (!timTreningSnapshot.exists) continue;

        var timTreningData = timTreningSnapshot.data() as Map<String, dynamic>;
        var pocetak = timTreningData['Početak'] as Timestamp?;
        var status = timTreningData['Status'] as String?;
        var mjesto = timTreningData['Mjesto'] as String?;

        treningsData.add({
          'DocId': doc.id,
          'Dolazak': data['Dolazak'] != null
              ? _formatTimestamp(data['Dolazak'])
              : null,
          'Odlazak': data['Odlazak'] != null
              ? _formatTimestamp(data['Odlazak'])
              : null,
          'Status': status == 'U budućnosti' ? status : data['Status'],
          'Mjesto': mjesto ?? 'N/A',
          'Datum': pocetak != null ? _formatDateOnly(pocetak) : 'N/A',
        });
      }
      return treningsData;
    });
  }

  String _formatTimestamp(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return DateFormat('dd.MM.yyyy HH:mm').format(date);
  }

  String _formatDateOnly(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return DateFormat('dd.MM.yyyy').format(date);
  }

  double _calculateAttendancePercentage(List<Map<String, dynamic>> trainings) {
    if (trainings.isEmpty) {
      return 0.0;
    }
    int attendedCount =
        trainings.where((trening) => trening['Status'] == 'Prisutna').length;
    return (attendedCount / trainings.length) * 100;
  }

  void _onSearchChanged() {
    setState(() {
      searchQuery = searchController.text.toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Upiši ime ili prezime...',
                hintStyle: TextStyle(color: Colors.purple[100]),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('Clanica')
                    .where('Tim', isEqualTo: userTim)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading members.'));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No members found.'));
                  }

                  final filteredDocs = snapshot.data?.docs
                      .where((doc) => doc['Uloga'] != 'Trener')
                      .toList();
                  final members = filteredDocs?.where((member) {
                    final memberData = member.data() as Map<String, dynamic>;
                    final ime = memberData['Ime'].toLowerCase();
                    final prezime = memberData['Prezime'].toLowerCase();
                    return ime.contains(searchQuery) ||
                        prezime.contains(searchQuery);
                  }).toList();

                  return ListView.builder(
                    itemCount: members?.length,
                    itemBuilder: (context, index) {
                      final memberDoc = members?[index];
                      final memberData =
                          memberDoc?.data() as Map<String, dynamic>;
                      final memberId = memberDoc!.id;

                      return StreamBuilder<List<Map<String, dynamic>>>(
                        stream: getMemberTrainingsStream(memberId),
                        builder: (context, trainingSnapshot) {
                          if (trainingSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return ListTile(
                                title: Text(
                                    '${memberData['Ime']} ${memberData['Prezime']}'),
                                subtitle: const Text('Loading...'));
                          }

                          if (trainingSnapshot.hasError) {
                            return ListTile(
                                title: Text(
                                    '${memberData['Ime']} ${memberData['Prezime']}'),
                                subtitle:
                                    const Text('Error loading training data.'));
                          }

                          final trainings = trainingSnapshot.data ?? [];

                          double attendancePercentage =
                              _calculateAttendancePercentage(trainings);

                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Container(
                              alignment: Alignment.centerLeft,
                              decoration: BoxDecoration(
                                color: Colors.purple[100],
                                borderRadius: const BorderRadius.all(
                                    Radius.circular(15.0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ExpansionTile(
                                    title: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            '${memberData['Ime']} ${memberData['Prezime']}'),
                                        Text(
                                          '${attendancePercentage.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            color: attendancePercentage >= 60
                                                ? Colors.green
                                                : Colors.red,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                    children: trainings.isNotEmpty
                                        ? trainings.map((trening) {
                                            return ListTile(
                                              title:
                                                  Text('${trening['Datum']}'),
                                              subtitle: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                      '${trening['Status'] ?? ''}'),
                                                  if (trening['Dolazak'] !=
                                                          null &&
                                                      trening['Dolazak']!
                                                          .isNotEmpty)
                                                    Text(
                                                        'Dolazak: ${trening['Dolazak']}'),
                                                  if (trening['Odlazak'] !=
                                                          null &&
                                                      trening['Odlazak']!
                                                          .isNotEmpty)
                                                    Text(
                                                        'Odlazak: ${trening['Odlazak']}'),
                                                ],
                                              ),
                                            );
                                          }).toList()
                                        : [
                                            const ListTile(
                                                title: Text('Nema podataka'))
                                          ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                }),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }
}
