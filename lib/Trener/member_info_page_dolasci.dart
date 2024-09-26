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
  //List<Map<String, dynamic>> trenings = [];
  Map<String, List<Map<String, dynamic>>> memberTrainings = {};
  Map<String, List<Map<String, dynamic>>> monthlyTrainings = {};

  @override
  void initState() {
    super.initState();
    _getAllTrenings();
    _calculateAttendancePercentage(widget.docId);
  }

  Future<void> _getAllTrenings() async {
    try {
      print('Fetching trainings for member: ${widget.docId}');

      QuerySnapshot clanicaTimTreningSnapshot = await FirebaseFirestore.instance
          .collection('Clanica_Tim_Trening')
          .where('ClanicaUID', isEqualTo: widget.docId)
          .get();

      if (clanicaTimTreningSnapshot.docs.isEmpty) {
        print('No documents found for ClanicaUID: ${widget.docId}');
        return;
      }

      List<Map<String, dynamic>> treningsData = [];
      Map<String, List<Map<String, dynamic>>> groupedTrainings = {};

      for (var doc in clanicaTimTreningSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        var timTreningId = data['Tim_TreningUID'];
        print('Fetching Tim_Trening for ID: $timTreningId');

        DocumentSnapshot timTreningSnapshot = await FirebaseFirestore.instance
            .collection('Tim_Trening')
            .doc(timTreningId)
            .get();

        if (!timTreningSnapshot.exists) {
          print('No Tim_Trening document found with ID: $timTreningId');
          continue;
        }

        var timTreningData = timTreningSnapshot.data() as Map<String, dynamic>;
        Timestamp? pocetak = timTreningData['Početak'];
        Timestamp? kraj = timTreningData['Kraj'];
        String mjesto = timTreningData['Mjesto'];
        String status = timTreningData['Status'];
        String monthKey = DateFormat('MM/yyyy').format(pocetak!.toDate());

        var trening = {
          'DocId': doc.id,
          'Dolazak': data['Dolazak'] != null
              ? _formatTimestamp(data['Dolazak'])
              : null,
          'Odlazak': data['Odlazak'] != null
              ? _formatTimestamp(data['Odlazak'])
              : null,
          'Status': data.containsKey('Status') ? data['Status'] : null,
          'Datum': pocetak != null ? _formatDateOnly(pocetak) : 'N/A',
          'Početak': pocetak != null ? _formatTimestamp(pocetak) : 'N/A',
          'Kraj': kraj != null ? _formatTimestamp(kraj) : 'N/A',
          'Mjesto': mjesto,
          'TrainingStatus': status,
        };

        treningsData.add(trening);

        if (!groupedTrainings.containsKey(monthKey)) {
          groupedTrainings[monthKey] = [];
        }
        groupedTrainings[monthKey]?.add(trening);
      }

      setState(() {
        memberTrainings[widget.docId] = treningsData;
        monthlyTrainings = groupedTrainings;
      });

      print('Trainings set in state: ${memberTrainings[widget.docId]}');
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

  Future<void> _showAddStatusDialog(BuildContext context, String docId) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AddStatusDialog(docId: docId);
      },
    );
  }

  double _calculateAttendancePercentage(String memberId) {
    if (memberTrainings[memberId] == null ||
        memberTrainings[memberId]!.isEmpty) {
      return 0.0;
    }
    List<Map<String, dynamic>> trainings = memberTrainings[memberId]!;
    int attendedCount =
        trainings.where((trening) => trening['Status'] == 'Prisutna').length;
    return (attendedCount / trainings.length) * 100;
  }

  @override
  Widget build(BuildContext context) {
    double attendancePercentage = _calculateAttendancePercentage(widget.docId);
    print('Att perc: $attendancePercentage');
    //print('Building widget with trenings: $trenings');
    List<String> months = monthlyTrainings.keys.toList();

    return DefaultTabController(
      length: months.length,
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
              const SizedBox(
                width: 25,
              ),
              Text(
                '${attendancePercentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: attendancePercentage >= 60 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          centerTitle: true,
          automaticallyImplyLeading: false,
          bottom: TabBar(
            isScrollable: true,
            tabs: months.map((month) => Tab(text: month)).toList(),
          ),
        ),
        body: monthlyTrainings.isEmpty
            ? Center(child: Text('No trainings found'))
            : TabBarView(
                children: months.map((month) {
                  List<Map<String, dynamic>> trainings =
                      monthlyTrainings[month] ?? [];
                  _calculateAttendancePercentage(widget.docId);

                  return Column(
                    children: [
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
                                        IconButton(
                                          icon: const Icon(
                                              Icons.add_circle_outline),
                                          onPressed: () {
                                            _showAddStatusDialog(
                                                context, trening['DocId']);
                                            _getAllTrenings();
                                          },
                                        ),
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
