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
  TextEditingController searchController = TextEditingController();
  String searchQuery = "";
  List<String> availableMonths = [];
  Map<String, List<Map<String, dynamic>>> monthlyTrainings = {};

  @override
  void initState() {
    super.initState();
    searchController.addListener(_onSearchChanged);
    fetchUserTim().then((_) => _fetchAvailableMonths());
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
              });
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching user Tim: $e');
    }
  }

  Future<void> _fetchAvailableMonths() async {
    DateTime now = DateTime.now();
    DateTime startDate = DateTime(now.year, now.month - 12);
    DateTime endDate = DateTime(now.year, now.month + 1);
    List<String> monthRange = _generateMonthRange(startDate, endDate);
    Set<String> monthsWithTrainings = {};

    try {
      CollectionReference teamCollectionRef =
          FirebaseFirestore.instance.collection('Clanica_Tim_Trening_2');
      QuerySnapshot teamSnapshot = await teamCollectionRef.get();

      for (var teamDoc in teamSnapshot.docs) {
        for (String monthId in monthRange) {
          CollectionReference monthCollectionRef =
              teamDoc.reference.collection(monthId);
          QuerySnapshot trainingSnapshot =
              await monthCollectionRef.limit(1).get();

          if (trainingSnapshot.docs.isNotEmpty) {
            monthsWithTrainings.add(monthId);
          }
        }
      }

      setState(() {
        availableMonths = monthsWithTrainings.toList()
          ..sort((a, b) => a.compareTo(b));
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching available months: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<String?> fetchMemberName(String memberId) async {
    try {
      final memberDoc = await FirebaseFirestore.instance
          .collection('Clanica')
          .doc(memberId)
          .get();

      if (memberDoc.exists) {
        final memberData = memberDoc.data();
        final status = memberData?['Status'];
        final uloga = memberData?['Uloga'];

        if (status == 'Upisana' && uloga == 'Plesač') {
          final name = memberData?['Ime'] ?? 'Unknown';
          final surname = memberData?['Prezime'] ?? 'Unknown';
          return '$name $surname';
        }
      }
      return null;
    } catch (e) {
      print('Error fetching member name for $memberId: $e');
      return null;
    }
  }

  Stream<Map<String, Map<String, dynamic>>> getMemberTrainingsStream(
      String monthId) {
    return FirebaseFirestore.instance
        .collection('Clanica_Tim_Trening_2')
        .doc(userTim)
        .collection(monthId)
        .snapshots()
        .asyncMap((snapshot) async {
      Map<String, Map<String, dynamic>> memberTrainings = {};

      for (var trainingDoc in snapshot.docs) {
        var trainingData = trainingDoc.data();
        var membersCollection = trainingDoc.reference.collection('Members');
        var memberSnapshot = await membersCollection.get();

        for (var memberDoc in memberSnapshot.docs) {
          var memberData = memberDoc.data();
          var memberId = memberData['ClanicaUID'] ?? 'Unknown Member';

          String? memberName = await fetchMemberName(memberId);

          if (memberName != null) {
            var trainingDetails = {
              'Dolazak': memberData['Dolazak'] != null
                  ? _formatTimestamp(memberData['Dolazak'])
                  : null,
              'Odlazak': memberData['Odlazak'] != null
                  ? _formatTimestamp(memberData['Odlazak'])
                  : null,
              'Status': memberData['Status'] ?? trainingData['Status'],
              'StatusTrening': trainingData['Status'],
              'Mjesto': trainingData['Mjesto'] ?? 'Unknown',
              'Datum': trainingData['Početak'] != null
                  ? _formatDateOnly(trainingData['Početak'])
                  : 'N/A',
            };

            if (!memberTrainings.containsKey(memberId)) {
              memberTrainings[memberId] = {
                'trainings': [],
                'presentCount': 0,
              };
            }
            (memberTrainings[memberId]!['trainings'] as List)
                .add(trainingDetails);

            if (trainingDetails['Status'] == 'Prisutna') {
              memberTrainings[memberId]!['presentCount'] =
                  memberTrainings[memberId]!['presentCount'] + 1;
            }
          }
        }
      }

      memberTrainings.forEach((key, value) {
        int totalTrainings = (value['trainings'] as List).length;
        int presentCount = value['presentCount'];
        double attendancePercentage =
            totalTrainings > 0 ? (presentCount / totalTrainings) * 100 : 0.0;
        value['attendancePercentage'] = attendancePercentage;
      });

      return memberTrainings;
    });
  }

  List<String> _generateMonthRange(DateTime start, DateTime end) {
    List<String> months = [];
    DateTime current = DateTime(start.year, start.month);

    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      months.add(DateFormat('MM-yyyy').format(current));
      current = DateTime(current.year, current.month + 1);
    }
    return months;
  }

  String _formatTimestamp(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return DateFormat('dd.MM.yyyy HH:mm').format(date);
  }

  String _formatDateOnly(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return DateFormat('dd.MM.yyyy').format(date);
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
          Expanded(
            child: ListView.builder(
              itemCount: availableMonths.length,
              itemBuilder: (context, index) {
                final monthId = availableMonths[index];

                return StreamBuilder<Map<String, Map<String, dynamic>>>(
                  stream: getMemberTrainingsStream(monthId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircularProgressIndicator();
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return ListTile(title: Text('No trainings available'));
                    }

                    final memberTrainings = snapshot.data ?? {};

                    return Container(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            color: Colors.purple[100],
                            borderRadius:
                                const BorderRadius.all(Radius.circular(15.0)),
                          ),
                          child: ExpansionTile(
                            title: Text(
                              monthId,
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            children: memberTrainings.entries.map((entry) {
                              final memberId = entry.key;
                              final trainingData = entry.value;
                              final trainings =
                                  trainingData['trainings'] as List;
                              final attendancePercentage =
                                  trainingData['attendancePercentage']
                                      as double;

                              return FutureBuilder<String?>(
                                future: fetchMemberName(memberId),
                                builder: (context, memberNameSnapshot) {
                                  final memberName = memberNameSnapshot.data;
                                  if (memberName == null) {
                                    return SizedBox.shrink();
                                  }

                                  return ExpansionTile(
                                    title: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(memberName),
                                        Text(
                                          '${attendancePercentage.toStringAsFixed(2)}%',
                                          style: TextStyle(
                                            color: attendancePercentage >= 60
                                                ? Colors.green
                                                : Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    children: trainings.map((training) {
                                      return ListTile(
                                        title: Text(
                                            '${training['Datum']} - ${training['Mjesto']}'),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Status: ${training['Status']}',
                                            ),
                                            if (training['Dolazak'] != null)
                                              Text(
                                                  'Dolazak: ${training['Dolazak']}'),
                                            if (training['Odlazak'] != null)
                                              Text(
                                                  'Odlazak: ${training['Odlazak']}'),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              );
                            }).toList(),
                          ),
                        ));
                  },
                );
              },
            ),
          ),
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
