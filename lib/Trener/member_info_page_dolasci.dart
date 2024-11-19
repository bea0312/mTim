import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mtim/Trener/add_status_dialog.dart';

class MemberInfoPageDolasci extends StatefulWidget {
  final String docId;

  MemberInfoPageDolasci({super.key, required this.docId});

  @override
  State<MemberInfoPageDolasci> createState() => _MemberInfoPageDolasciState();
}

class _MemberInfoPageDolasciState extends State<MemberInfoPageDolasci> {
  Map<String, List<Map<String, dynamic>>> monthlyTrainings = {};
  List<String> availableMonths = [];
  bool isLoading = true;
  String currentMonth = DateFormat('MM-yyyy').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _fetchAvailableMonths();
    _getTrainingsForCurrentMonth();
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

  Future<void> _getTrainingsForMonth(String monthId) async {
    if (monthlyTrainings.containsKey(monthId)) return;

    setState(() {
      isLoading = true;
    });

    List<Map<String, dynamic>> monthTrainings = [];
    try {
      CollectionReference teamCollectionRef =
          FirebaseFirestore.instance.collection('Clanica_Tim_Trening_2');
      QuerySnapshot teamSnapshot = await teamCollectionRef.get();

      for (var teamDoc in teamSnapshot.docs) {
        String teamId = teamDoc.id;

        CollectionReference monthCollectionRef =
            teamDoc.reference.collection(monthId);
        QuerySnapshot trainingSnapshot = await monthCollectionRef.get();

        if (trainingSnapshot.docs.isNotEmpty) {
          for (var trainingDoc in trainingSnapshot.docs) {
            CollectionReference membersCollectionRef =
                trainingDoc.reference.collection('Members');
            QuerySnapshot membersSnapshot = await membersCollectionRef
                .where('ClanicaUID', isEqualTo: widget.docId)
                .get();

            if (membersSnapshot.docs.isNotEmpty) {
              Map<String, dynamic> trainingData =
                  trainingDoc.data() as Map<String, dynamic>;
              Timestamp startTimestamp =
                  trainingData['Početak'] ?? Timestamp.now();
              Timestamp endTimestamp = trainingData['Kraj'] ?? Timestamp.now();

              DocumentSnapshot memberDoc = await FirebaseFirestore.instance
                  .collection('Clanica_Tim_Trening_2')
                  .doc(teamId)
                  .collection(monthId)
                  .doc(trainingDoc.id)
                  .collection('Members')
                  .doc(widget.docId)
                  .get();
              Map<String, dynamic>? memberData =
                  memberDoc.data() as Map<String, dynamic>?;

              var trening = {
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
                'Datum': _formatDateOnly(startTimestamp),
                'Tim': trainingData['Tim'] ?? 'Unknown',
                'Team': teamId
              };

              monthTrainings.add(trening);
            }
          }
        }
      }

      monthTrainings
          .sort((a, b) => b['startTimestamp'].compareTo(a['startTimestamp']));

      setState(() {
        monthlyTrainings[monthId] = monthTrainings;
      });
    } catch (e) {
      print('Error fetching trainings for $monthId: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _getTrainingsForCurrentMonth() async {
    await _getTrainingsForMonth(currentMonth);
  }

  String _formatTimeOnly(dynamic timestamp) {
    if (timestamp == null || timestamp is! Timestamp) {
      return 'Unknown';
    }
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

  Future<void> _showAddStatusDialog(String memberId, String teamId,
      String trainingId, String monthYear) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AddStatusDialog(
          memberId: memberId,
          teamId: teamId,
          trainingId: trainingId,
          monthYear: monthYear,
        );
      },
    );
  }

  double _calculateAttendancePercentage() {
    int totalTrainings = 0;
    int attendedCount = 0;

    for (var trainings in monthlyTrainings.values) {
      for (var trening in trainings) {
        if (trening.containsKey('Status')) {
          totalTrainings++;
          if (trening['Status'] == 'Prisutna') {
            attendedCount++;
          }
        }
      }
    }

    return totalTrainings == 0 ? 0.0 : (attendedCount / totalTrainings) * 100;
  }

  @override
  Widget build(BuildContext context) {
    double attendancePercentage = _calculateAttendancePercentage();

    return DefaultTabController(
      length: availableMonths.length,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.pie_chart_rounded,
                size: 35,
                color: attendancePercentage >= 60 ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 25),
              Text(
                '${attendancePercentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: attendancePercentage >= 60 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          centerTitle: true,
          bottom: isLoading
              ? null
              : TabBar(
                  isScrollable: true,
                  tabs:
                      availableMonths.map((month) => Tab(text: month)).toList(),
                  onTap: (index) {
                    String selectedMonth = availableMonths[index];
                    _getTrainingsForMonth(selectedMonth);
                  },
                ),
        ),
        body: isLoading
            ? Center(child: CircularProgressIndicator())
            : TabBarView(
                children: availableMonths.map((month) {
                  List<Map<String, dynamic>> trainings =
                      monthlyTrainings[month] ?? [];

                  return trainings.isEmpty
                      ? Center(child: Text('No trainings found for $month'))
                      : ListView.builder(
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
                                            color: Colors.green)
                                      else if (trening['Status'] == 'Odsutna')
                                        Icon(Icons.block_outlined,
                                            color: Colors.red)
                                      else
                                        IconButton(
                                          icon: const Icon(
                                              Icons.add_circle_outline),
                                          onPressed: () {
                                            _showAddStatusDialog(
                                                widget.docId,
                                                trening['Team'],
                                                trening['trainingId'],
                                                trening['monthId']);
                                          },
                                        ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          'Dolazak: ${trening['Dolazak'] ?? 'N/A'}'),
                                      Text(
                                          'Odlazak: ${trening['Odlazak'] ?? 'N/A'}'),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                }).toList(),
              ),
      ),
    );
  }
}
