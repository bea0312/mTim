import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mtim/Trener/add_new_trainig_dialog.dart';
import 'package:mtim/Trener/edit_training_dialog.dart';
import 'package:mtim/firebase_api.dart';
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
                trainingsFuture = _getAllTrainings();
              });
              print('Called _getAllTrainings');
            } else {
              print('User is not a Trener');
            }
          } else {
            print('No user document found');
          }
        } else {
          print('User email is null');
        }
      } else {
        print('User is null');
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

  Future<List<Map<String, dynamic>>> _getAllTrainings() async {
    List<Map<String, dynamic>> allTrainings = [];

    try {
      QuerySnapshot trainingsSnapshot = await FirebaseFirestore.instance
          .collection('Tim_Trening')
          .where('Tim', isEqualTo: userTim)
          .get();

      for (var trainingDoc in trainingsSnapshot.docs) {
        String status = trainingDoc['Status'];
        String mjesto = trainingDoc['Mjesto'];
        Timestamp start = trainingDoc['Početak'];
        Timestamp end = trainingDoc['Kraj'];

        allTrainings.add({
          'DocId': trainingDoc.id,
          'Početak': _formatTimeOnly(start),
          'Kraj': _formatTimeOnly(end),
          'Mjesto': mjesto,
          'Status': status,
          'Datum': _formatDateOnly(start),
        });
      }

      return allTrainings;
    } catch (e) {
      print(e);
      return [];
    }
  }

  @override
  void initState() {
    super.initState();
    fetchUserTim();
    _getAllTrainings();
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

  Future<void> _editTraining(BuildContext context, String id) async {
    return showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return EditTrainingDialog(
              docId: id,
              onUpdate: (updatedData) {
                setState(() {
                  for (var training in trainingsData) {
                    if (training['DocId'] == id) {
                      training['Mjesto'] =
                          updatedData['Mjesto'] ?? training['Mjesto'];
                      if (training['Početak'] != null) {
                        training['Početak'] =
                            _formatDateOnly(updatedData['Početak']);
                      }
                      if (training['Kraj'] != null) {
                        training['Kraj'] = _formatDateOnly(updatedData['Kraj']);
                      }
                    }
                  }
                });
              });
        });
  }

  void trainingStart(String trainingId) async {
    Map<String, dynamic> updateData = {'Status': 'U tijeku'};

    await FirebaseFirestore.instance
        .collection('Tim_Trening')
        .doc(trainingId)
        .update(updateData);

    NfcManager.instance.startSession(onDiscovered: (NfcTag badge) async {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('NFC scanning started.')),
      );

      _nfcStartSessionTimer = Timer(Duration(minutes: 1), () {
        if (mounted) {
          NfcManager.instance.stopSession();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('NFC session automatically stopped.')),
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
            .collection('Clanica_Tim_Trening')
            .where('ClanicaUID', isEqualTo: tagRecord)
            .where('Tim_TreningUID', isEqualTo: trainingId)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          var docId = querySnapshot.docs.first.id;
          await FirebaseFirestore.instance
              .collection('Clanica_Tim_Trening')
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
          SnackBar(content: const Text('NFC scanning stopped.')),
        );
      }
    });
  }

  void trainingEnd(String trainingId) async {
    Map<String, dynamic> updateData = {'Status': 'Odrađen'};

    await FirebaseFirestore.instance
        .collection('Tim_Trening')
        .doc(trainingId)
        .update(updateData);

    NfcManager.instance.startSession(onDiscovered: (NfcTag badge) async {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('NFC scanning started.')),
      );

      _nfcSessionTimer = Timer(Duration(minutes: 1), () {
        if (mounted) {
          NfcManager.instance.stopSession();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('NFC session automatically stopped.')),
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
            .collection('Clanica_Tim_Trening')
            .where('Tim_TreningUID', isEqualTo: trainingId)
            .get();

        for (var doc in querySnapshot.docs) {
          var documentData = doc.data() as Map<String, dynamic>;
          var docId = doc.id;

          if (documentData['Dolazak'] == null) {
            await FirebaseFirestore.instance
                .collection('Clanica_Tim_Trening')
                .doc(docId)
                .update({
              'Status': 'Odsutna',
              'Odlazak': Timestamp.now(),
            });
            print("Document updated to 'Odsutna': $docId");
          } else {
            await FirebaseFirestore.instance
                .collection('Clanica_Tim_Trening')
                .doc(docId)
                .update({'Odlazak': Timestamp.now()});
            print("Document updated: $docId");
          }
        }
      } catch (e) {
        print('Error: $e');
      } finally {
        if (_nfcSessionTimer?.isActive ?? false) {
          _nfcSessionTimer?.cancel();
        }
        NfcManager.instance.stopSession();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('NFC scanning stopped.')),
        );
      }
    });
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
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No trainings available'));
          } else {
            trainingsData = snapshot.data!;

            return Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          _openNewTrainigDialog(context);
                          FirebaseApi().initPushNotifications();
                          _getAllTrainings();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            borderRadius:
                                const BorderRadius.all(Radius.circular(15.0)),
                            color: Colors.white,
                            border: Border.all(color: Colors.purple, width: 2),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, color: Colors.purple),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
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
                                      Text('${training['Datum']}'),
                                      PopupMenuButton<int>(
                                        icon: Icon(Icons.more_horiz),
                                        onSelected: (int value) {
                                          if (value == 0) {
                                            _editTraining(
                                                context, training['DocId']);
                                          } else if (value == 1) {
                                            FirebaseFirestore.instance
                                                .collection('Tim_Trening')
                                                .doc(training['DocId'])
                                                .delete();
                                          } else if (value == 2) {
                                            trainingStart(training['DocId']);
                                          } else if (value == 3) {
                                            trainingEnd(training['DocId']);
                                          }
                                        },
                                        itemBuilder: (BuildContext context) {
                                          return [
                                            const PopupMenuItem<int>(
                                              value: 0,
                                              child: Row(
                                                children: [
                                                  Icon(Icons.edit_outlined),
                                                  SizedBox(
                                                    width: 10,
                                                  ),
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
                                                  SizedBox(
                                                    width: 10,
                                                  ),
                                                  Text('Izbriši')
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem<int>(
                                              value: 2,
                                              child: Row(
                                                children: [
                                                  Icon(Icons.check_circle),
                                                  SizedBox(
                                                    width: 10,
                                                  ),
                                                  Text('Početak')
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem<int>(
                                              value: 3,
                                              child: Row(
                                                children: [
                                                  Icon(Icons.not_interested),
                                                  SizedBox(
                                                    width: 10,
                                                  ),
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
                            }))
                  ],
                ),
              ),
            );
          }
        });
  }
}
