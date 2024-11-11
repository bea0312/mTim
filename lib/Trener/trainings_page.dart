import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mtim/Trener/add_new_trainig_dialog.dart';
import 'package:mtim/Trener/edit_training_dialog.dart';
import 'package:nfc_manager/nfc_manager.dart';

class TrainingsPage extends StatefulWidget {
  const TrainingsPage({super.key});

  @override
  State<TrainingsPage> createState() => _TrainingsPageState();
}

class _TrainingsPageState extends State<TrainingsPage> {
  String? userTim;
  bool isLoading = true;
  late Future<List<Map<String, dynamic>>> trainingsFuture = Future.value([]);
  List<Map<String, dynamic>> trainingsData = [];
  Timer? _nfcStartSessionTimer;
  Timer? _nfcSessionTimer;

  DateTime startDate = DateTime(2023, 11, 1);
  DateTime endDate = DateTime(2024, 12, 31);
  String _formatMonthId(DateTime date) => DateFormat('MM-yyyy').format(date);

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
                trainingsFuture =
                    _getAllTrainings(userTim!, startDate, endDate);
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

  Future<List<Map<String, dynamic>>> _getAllTrainings(
      String teamId, DateTime startDate, DateTime endDate) async {
    List<Map<String, dynamic>> allTrainings = [];
    List<String> monthYears = _generateMonthRange(startDate, endDate);
    try {
      for (String monthId in monthYears) {
        CollectionReference monthCollectionRef = FirebaseFirestore.instance
            .collection('Clanica_Tim_Trening_2')
            .doc(teamId)
            .collection(monthId);

        QuerySnapshot trainingSnapshot = await monthCollectionRef.get();

        for (var trainingDoc in trainingSnapshot.docs) {
          Map<String, dynamic> trainingData =
              trainingDoc.data() as Map<String, dynamic>;

          Timestamp startTimestamp = trainingData['Početak'];
          Timestamp endTimestamp = trainingData['Kraj'];

          allTrainings.add({
            'trainingId': trainingDoc.id,
            'monthId': monthId,
            'startTimestamp': startTimestamp,
            'Početak': _formatTimeOnly(startTimestamp),
            'Kraj': _formatTimeOnly(endTimestamp),
            'Mjesto': trainingData['Mjesto'],
            'Status': trainingData['Status'],
            'Date': _formatDateOnly(startTimestamp),
            'Tim': trainingData['Tim'],
          });
        }
      }

      allTrainings.sort((a, b) {
        return b['startTimestamp'].compareTo(a['startTimestamp']);
      });
    } catch (e) {
      print('Error fetching trainings: $e');
    }

    return allTrainings;
  }

  @override
  void initState() {
    super.initState();
    fetchUserTim();
  }

  Future<void> _openNewTrainigDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddNewTrainingDialog(
          team: userTim,
        );
      },
    );
  }

  Future<void> _editTraining(BuildContext context, String teamName,
      String monthYear, String id) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return EditTrainingDialog(
          teamName: teamName,
          monthYear: monthYear,
          docId: id,
          onUpdate: (updatedData) {
            setState(() {
              for (var training in trainingsData) {
                if (training['DocId'] == id) {
                  training['Mjesto'] =
                      updatedData['Mjesto'] ?? training['Mjesto'];
                  if (updatedData['Početak'] != null) {
                    training['Početak'] =
                        _formatDateOnly(updatedData['Početak']);
                  }
                  if (updatedData['Kraj'] != null) {
                    training['Kraj'] = _formatDateOnly(updatedData['Kraj']);
                  }
                }
              }
            });
          },
        );
      },
    );
  }

  void deleteTraining(
      String teamName, String monthYear, String trainingId) async {
    try {
      DocumentReference trainingRef = FirebaseFirestore.instance
          .collection('Clanica_Tim_Trening_2')
          .doc(teamName)
          .collection(monthYear)
          .doc(trainingId);

      DocumentSnapshot trainingSnapshot = await trainingRef.get();
      if (!trainingSnapshot.exists) {
        throw Exception("Training document not found: ${trainingRef.path}");
      }

      QuerySnapshot membersSnapshot =
          await trainingRef.collection('Members').get();
      for (var doc in membersSnapshot.docs) {
        await doc.reference.delete();
      }

      await trainingRef.delete();

      print("Training $trainingId deleted successfully!");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Training $trainingId deleted successfully!")),
      );
    } catch (e) {
      print("Error deleting training: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting training: $e")),
      );
    }
  }

  void trainingStart(
      String teamName, String monthYear, String trainingId) async {
    Map<String, dynamic> updateData = {'Status': 'U tijeku'};

    await FirebaseFirestore.instance
        .collection('Clanica_Tim_Trening_2')
        .doc(teamName)
        .collection(monthYear)
        .doc(trainingId)
        .update(updateData);

    NfcManager.instance.startSession(onDiscovered: (NfcTag badge) async {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('NFC scanning started.')),
      );

      _nfcStartSessionTimer = Timer(Duration(seconds: 5), () {
        if (mounted) {
          NfcManager.instance.stopSession();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('NFC session automatically stopped.')),
          );
        }
      });

      try {
        String tagRecord = "";
        var ndef = Ndef.from(badge);
        if (ndef != null && ndef.cachedMessage != null) {
          for (var record in ndef.cachedMessage!.records) {
            tagRecord =
                "${String.fromCharCodes(record.payload.sublist(record.payload[0] + 1))}";
            print("NFC tag data: $tagRecord");
          }
        }

        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection('Clanica_Tim_Trening_2')
            .doc(teamName)
            .collection(monthYear)
            .doc(trainingId)
            .collection('Members')
            .where('ClanicaUID', isEqualTo: tagRecord)
            .where('Tim_TreningUID', isEqualTo: trainingId)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          var docId = querySnapshot.docs.first.id;
          await FirebaseFirestore.instance
              .collection('Clanica_Tim_Trening_2')
              .doc(teamName)
              .collection(monthYear)
              .doc(trainingId)
              .collection('Members')
              .doc(docId)
              .update({'Dolazak': Timestamp.now(), 'Status': 'Prisutna'});
          print("Document updated: $docId");
        }
      } catch (e) {
        print('Error: $e');
      } finally {
        if (_nfcStartSessionTimer?.isActive ?? false) {
          _nfcStartSessionTimer?.cancel();
        }
        NfcManager.instance.stopSession();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('NFC scanning stopped.')),
        );
      }
    });
  }

  void trainingEnd(String teamName, String monthYear, String trainingId) async {
    Map<String, dynamic> updateData = {'Status': 'Odrađen'};

    try {
      DocumentReference trainingRef = FirebaseFirestore.instance
          .collection('Clanica_Tim_Trening_2')
          .doc(teamName)
          .collection(monthYear)
          .doc(trainingId);
      await trainingRef.update(updateData);
      QuerySnapshot membersSnapshot =
          await trainingRef.collection('Members').get();

      for (var doc in membersSnapshot.docs) {
        var memberData = doc.data() as Map<String, dynamic>;
        var docId = doc.id;

        if (memberData['Dolazak'] == null) {
          await FirebaseFirestore.instance
              .collection('Clanica_Tim_Trening_2')
              .doc(teamName)
              .collection(monthYear)
              .doc(trainingId)
              .collection('Members')
              .doc(docId)
              .update({
            'Status': 'Odsutna',
          });
        } else {
          await FirebaseFirestore.instance
              .collection('Clanica_Tim_Trening_2')
              .doc(teamName)
              .collection(monthYear)
              .doc(trainingId)
              .collection('Members')
              .doc(docId)
              .update({
            'Odlazak': Timestamp.now(),
          });
          print("Member $docId 'Odlazak' updated");
        }
      }

      NfcManager.instance.stopSession();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('NFC session stopped.')),
      );
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  void dispose() {
    _nfcSessionTimer?.cancel();
    _nfcStartSessionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: trainingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return const Center(child: Text('Error loading trainings'));
        } else {
          trainingsData = snapshot.data!;

          return Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      _openNewTrainigDialog(context);
                      _getAllTrainings(userTim!, startDate, endDate);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(15.0)),
                        color: Colors.white,
                        border: Border.all(color: Colors.purple, width: 2),
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, color: Colors.purple),
                            SizedBox(width: 8),
                            Text('Novi trening',
                                style: TextStyle(color: Colors.purple)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  trainingsData.isEmpty
                      ? const Center(child: Text('No trainings available'))
                      : Expanded(
                          child: ListView.builder(
                            itemCount: trainingsData.length,
                            itemBuilder: (context, index) {
                              final training = trainingsData[index];
                              return Card(
                                color: Colors.purple[100],
                                child: ListTile(
                                  title: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${training['Date']}'),
                                      PopupMenuButton<int>(
                                        icon: Icon(Icons.more_horiz),
                                        onSelected: (int value) {
                                          final monthId = training['monthId'];
                                          final trainingId =
                                              training['trainingId'];

                                          if (value == 0) {
                                            _editTraining(context, userTim!,
                                                monthId, trainingId);
                                          } else if (value == 1) {
                                            deleteTraining(
                                                userTim!, monthId, trainingId);
                                          } else if (value == 2) {
                                            trainingStart(
                                                userTim!, monthId, trainingId);
                                          } else if (value == 3) {
                                            trainingEnd(
                                                userTim!, monthId, trainingId);
                                          }
                                        },
                                        itemBuilder: (BuildContext context) {
                                          return [
                                            const PopupMenuItem<int>(
                                              value: 0,
                                              child: Row(
                                                children: [
                                                  Icon(Icons.edit_outlined),
                                                  SizedBox(width: 10),
                                                  Text('Uredi')
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem<int>(
                                              value: 1,
                                              child: Row(
                                                children: [
                                                  Icon(Icons
                                                      .delete_outline_rounded),
                                                  SizedBox(width: 10),
                                                  Text('Izbriši')
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem<int>(
                                              value: 2,
                                              child: Row(
                                                children: [
                                                  Icon(Icons.check_circle),
                                                  SizedBox(width: 10),
                                                  Text('Početak')
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem<int>(
                                              value: 3,
                                              child: Row(
                                                children: [
                                                  Icon(Icons.not_interested),
                                                  SizedBox(width: 10),
                                                  Text('Kraj')
                                                ],
                                              ),
                                            ),
                                          ];
                                        },
                                      ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          '${training['Početak']} - ${training['Kraj']}'),
                                      Text('${training['Mjesto']}'),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}
