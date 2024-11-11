import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mtim/notification_service.dart';

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

    String? email = user?.email;
    print('User email: $email');

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('Clanica')
          .where('Email', isEqualTo: email)
          .get();

      print('Number of documents found: ${querySnapshot.docs.length}');

      if (querySnapshot.docs.isNotEmpty) {
        DocumentSnapshot documentSnapshot = querySnapshot.docs.first;
        userId = documentSnapshot.id;
        print('User id: $userId');

        DateTime now = DateTime.now();
        DateTime startDate = DateTime(now.year, now.month - 12);
        DateTime endDate = DateTime(now.year, now.month + 1);

        await _getAllTrainings(userId!, startDate, endDate);
      } else {
        print("No member found with email $email");
      }
    } catch (e) {
      print("Error getting member by email: $e");
    }
  }

  Future<void> _getAllTrainings(
      String memberId, DateTime startDate, DateTime endDate) async {
    List<Map<String, dynamic>> allTrainings = [];
    List<String> monthYears = _generateMonthRange(startDate, endDate);
    print(
        'Fetching trainings for memberId: $memberId, from ${startDate.toIso8601String()} to ${endDate.toIso8601String()}');
    print('Months to fetch: $monthYears');

    try {
      for (String monthId in monthYears) {
        CollectionReference teamCollectionRef =
            FirebaseFirestore.instance.collection('Clanica_Tim_Trening_2');

        QuerySnapshot teamSnapshot = await teamCollectionRef.get();
        print('Number of teams found: ${teamSnapshot.docs.length}');

        for (var teamDoc in teamSnapshot.docs) {
          CollectionReference monthCollectionRef =
              teamDoc.reference.collection(monthId);
          QuerySnapshot trainingSnapshot = await monthCollectionRef.get();
          print(
              'Number of training documents found for team ${teamDoc.id} in month $monthId: ${trainingSnapshot.docs.length}');

          for (var trainingDoc in trainingSnapshot.docs) {
            CollectionReference membersCollectionRef =
                trainingDoc.reference.collection('Members');
            QuerySnapshot membersSnapshot = await membersCollectionRef
                .where('ClanicaUID', isEqualTo: memberId)
                .get();

            print(
                'Number of members found for training ${trainingDoc.id}: ${membersSnapshot.docs.length}');

            if (membersSnapshot.docs.isNotEmpty) {
              Map<String, dynamic> trainingData =
                  trainingDoc.data() as Map<String, dynamic>;
              Timestamp startTimestamp =
                  trainingData['Početak'] ?? Timestamp.now();
              Timestamp endTimestamp = trainingData['Kraj'] ?? Timestamp.now();

              DocumentReference memberDocRef = FirebaseFirestore.instance
                  .collection('Clanica_Tim_Trening_2')
                  .doc(trainingData['Tim'])
                  .collection(monthId)
                  .doc(trainingDoc.id)
                  .collection('Members')
                  .doc(memberId);

              DocumentSnapshot memberDoc = await memberDocRef.get();
              Map<String, dynamic>? memberData =
                  memberDoc.data() as Map<String, dynamic>?;

              allTrainings.add({
                'trainingId': trainingDoc.id,
                'monthId': monthId,
                'startTimestamp': startTimestamp,
                'Početak': _formatTimeOnly(startTimestamp),
                'Kraj': _formatTimeOnly(endTimestamp),
                'Mjesto': trainingData['Mjesto'] ?? 'Unknown',
                'Status': memberData != null && memberData.containsKey('Status')
                    ? memberData['Status']
                    : 'Unknown',
                'Dolazak':
                    memberData != null && memberData.containsKey('Dolazak')
                        ? _formatTimeOnly(memberData['Dolazak'])
                        : '',
                'Odlazak':
                    memberData != null && memberData.containsKey('Odlazak')
                        ? _formatTimeOnly(memberData['Odlazak'])
                        : '',
                'Date': _formatDateOnly(startTimestamp),
                'Tim': trainingData['Tim'] ?? 'Unknown',
                'IsToday': _checkIfTrainingToday(startTimestamp),
              });

              if (_checkIfTrainingToday(startTimestamp)) {
                NotificationService().showNotificationDanasTrening(
                    trainingData['Mjesto'], startTimestamp.toDate());
              }
            }
          }
        }
      }

      allTrainings
          .sort((a, b) => b['startTimestamp'].compareTo(a['startTimestamp']));

      Map<String, List<Map<String, dynamic>>> groupedTrainings = {};
      for (var training in allTrainings) {
        String monthKey = training['monthId'];
        if (!groupedTrainings.containsKey(monthKey)) {
          groupedTrainings[monthKey] = [];
        }
        groupedTrainings[monthKey]?.add(training);
      }

      print('Grouped trainings: ${groupedTrainings.keys.toList()}');

      setState(() {
        monthlyTrainings = groupedTrainings;
      });
    } catch (e) {
      print('Error fetching trainings: $e');
    }
  }

  String _formatTimeOnly(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return DateFormat('HH:mm').format(date);
  }

  String _formatDateOnly(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return DateFormat('dd.MM.yyyy').format(date);
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

  bool _checkIfTrainingToday(Timestamp? timestamp) {
    if (timestamp == null) return false;
    DateTime trainingDate = timestamp.toDate();
    DateTime today = DateTime.now();

    return trainingDate.year == today.year &&
        trainingDate.month == today.month &&
        trainingDate.day == today.day;
  }

  double _calculateAttendancePercentage(List<Map<String, dynamic>> trainings) {
    if (trainings.isEmpty) return 0.0;

    int attendedCount =
        trainings.where((trening) => trening['Status'] == 'Prisutna').length;
    return (attendedCount / trainings.length) * 100;
  }

  @override
  Widget build(BuildContext context) {
    List<String> sortedMonthKeys = monthlyTrainings.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return DefaultTabController(
      length: sortedMonthKeys.length,
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
                                  color: trening['IsToday'] == true
                                      ? Colors.green[100]
                                      : Colors.purple[100],
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(15.0)),
                                ),
                                child: ListTile(
                                  title: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                          '${trening['Date']}, ${trening['Početak']} - ${trening['Kraj']}'),
                                      if (trening['Status'] == 'Prisutna')
                                        Icon(Icons.check_circle,
                                            color: Colors.green),
                                      if (trening['Status'] == 'Odsutna')
                                        Icon(Icons.block_outlined,
                                            color: Colors.red),
                                      if (trening['Status'] == 'Unknown')
                                        Icon(Icons.watch_later_outlined),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('${trening['Mjesto']}'),
                                      Text('Dolazak: ${trening['Dolazak']}'),
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
