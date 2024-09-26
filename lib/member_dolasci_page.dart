import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MemberDolasciPage extends StatefulWidget {
  const MemberDolasciPage({super.key});

  @override
  State<MemberDolasciPage> createState() => _MemberDolasciPageState();
}

class _MemberDolasciPageState extends State<MemberDolasciPage> {
  Map<String, List<Map<String, dynamic>>> monthlyTrainings = {};
  User? user = FirebaseAuth.instance.currentUser;
  String? userId;

  @override
  void initState() {
    super.initState();
    _getMemberData();
  }

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
        userId = documentSnapshot.id;
        print('User id: $userId');

        _getAllTrainings();
      } else {
        print("No member found with email $email");
      }
    } catch (e) {
      print("Error getting member by email: $e");
    }
  }

  Future<void> _getAllTrainings() async {
    if (userId == null) return;

    try {
      QuerySnapshot trainingSnapshot = await FirebaseFirestore.instance
          .collection('Clanica_Tim_Trening')
          .where('ClanicaUID', isEqualTo: userId)
          .get();

      if (trainingSnapshot.docs.isEmpty) {
        print('No documents found for ClanicaUID: $userId');
        return;
      }

      Map<String, List<Map<String, dynamic>>> groupedTrainings = {};

      for (var doc in trainingSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        var timTreningId = data['Tim_TreningUID'];
        DocumentSnapshot timTreningSnapshot = await FirebaseFirestore.instance
            .collection('Tim_Trening')
            .doc(timTreningId)
            .get();

        if (!timTreningSnapshot.exists) {
          print('No Tim_Trening document found with ID: $timTreningId');
          continue;
        }

        var timTreningData = timTreningSnapshot.data() as Map<String, dynamic>;
        Timestamp pocetak = timTreningData['Početak'];
        String monthKey = DateFormat('MM/yyyy').format(pocetak.toDate());

        var treningData = {
          'DocId': doc.id,
          'Dolazak': data['Dolazak'] != null
              ? _formatTimestamp(data['Dolazak'])
              : null,
          'Odlazak': data['Odlazak'] != null
              ? _formatTimestamp(data['Odlazak'])
              : null,
          'Status': data['Status'],
          'Datum': _formatDateOnly(pocetak),
          'Početak': _formatTimestamp(pocetak),
          'Kraj': _formatTimestamp(timTreningData['Kraj']),
          'Mjesto': timTreningData['Mjesto'],
          'TrainingStatus': timTreningData['Status'],
        };

        if (!groupedTrainings.containsKey(monthKey)) {
          groupedTrainings[monthKey] = [];
        }
        groupedTrainings[monthKey]?.add(treningData);
      }

      setState(() {
        monthlyTrainings = groupedTrainings;
        print('Grouped trainings: $monthlyTrainings');
      });
    } catch (e) {
      print('Error retrieving trainings: $e');
    }
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
    if (trainings.isEmpty) return 0.0;

    int attendedCount =
        trainings.where((trening) => trening['Status'] == 'Prisutna').length;
    return (attendedCount / trainings.length) * 100;
  }

  @override
  Widget build(BuildContext context) {
    List<DateTime> sortedMonths = monthlyTrainings.keys.map((month) {
      return DateFormat('MM/yyyy').parse(month);
    }).toList()
      ..sort((a, b) => b.compareTo(a));

    List<String> sortedMonthKeys = sortedMonths.map((dateTime) {
      return DateFormat('MM/yyyy').format(dateTime);
    }).toList();

    List<String> months = monthlyTrainings.keys.toList();

    return DefaultTabController(
      length: months.length,
      child: Scaffold(
        appBar: AppBar(
          bottom: TabBar(
            isScrollable: true,
            tabs: sortedMonthKeys.map((month) => Tab(text: month)).toList(),
          ),
        ),
        body: sortedMonthKeys.isEmpty
            ? Center(child: Text('No trainings found'))
            : TabBarView(
                children: sortedMonthKeys.map((month) {
                  List<Map<String, dynamic>> trainings =
                      monthlyTrainings[month] ?? [];
                  double attendancePercentage =
                      _calculateAttendancePercentage(trainings);

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.pie_chart_rounded,
                              size: 35,
                              color: attendancePercentage >= 60
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            SizedBox(width: 10),
                            Text(
                              '${attendancePercentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: attendancePercentage >= 60
                                    ? Colors.green
                                    : Colors.red,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: trainings.length,
                          itemBuilder: (context, index) {
                            Map<String, dynamic> trening = trainings[index];
                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.purple[100],
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(15.0)),
                                ),
                                child: ListTile(
                                  title: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(trening['Datum']),
                                      if (trening['Status'] == 'Prisutna')
                                        Icon(Icons.check_circle,
                                            color: Colors.green),
                                      if (trening['Status'] == 'Odsutna')
                                        Icon(Icons.block_outlined,
                                            color: Colors.red),
                                      if (trening['Status'] == null)
                                        Icon(Icons.watch_later_outlined),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (trening['Dolazak'] != null)
                                        Text('Dolazak: ${trening['Dolazak']}'),
                                      if (trening['Odlazak'] != null)
                                        Text('Odlazak: ${trening['Odlazak']}'),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
      ),
    );
  }
}
