import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AddNewTrainingDialog extends StatefulWidget {
  final String? team;
  const AddNewTrainingDialog({super.key, required this.team});

  @override
  State<AddNewTrainingDialog> createState() => _AddNewTrainingDialogState();
}

class _AddNewTrainingDialogState extends State<AddNewTrainingDialog> {
  DateTime? start;
  DateTime? end;
  String dropdownValue = 'OŠ Ljubo Babić - dvorana';
  String? memberId;
  String? trainingID;

  Future<void> saveTrainingToFirestore() async {
    // Ensure 'start' and 'end' are not null
    if (start == null || end == null) {
      // Handle the case where the start or end time is not set
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both start and end time')),
      );
      return;
    }

    final newTraining = {
      'Početak': start,
      'Kraj': end,
      'Mjesto': dropdownValue,
      'Tim': widget.team,
      'Status': 'U budućnosti'
    };

    String monthYear = DateFormat('MM-yyyy').format(start!);
    print('Month-Year: $monthYear'); // Log for debugging

    // Ensure the team document exists
    DocumentReference teamDocRef = FirebaseFirestore.instance
        .collection('Clanica_Tim_Trening_2')
        .doc(widget.team);

    DocumentSnapshot teamSnapshot = await teamDocRef.get();
    if (!teamSnapshot.exists) {
      await teamDocRef.set({'name': widget.team});
    }

    // Creating the collection reference for the specific month-year
    try {
      CollectionReference monthCollectionRef = teamDocRef.collection(monthYear);

      // Add new training document
      DocumentReference trainingRef = await monthCollectionRef.add(newTraining);
      trainingID = trainingRef.id;

      // Get members of the team
      QuerySnapshot membersSnapshot = await FirebaseFirestore.instance
          .collection('Clanica')
          .where('Tim', isEqualTo: widget.team)
          .get();

      // Add links between the members and the training
      for (var memberDoc in membersSnapshot.docs) {
        memberId = memberDoc.id;

        final memberTrainingLink = {
          'ClanicaUID': memberId,
          'Tim_TreningUID': trainingID
        };
        await monthCollectionRef
            .doc(trainingID)
            .collection('Members')
            .doc(memberId)
            .set(memberTrainingLink);
      }

      // Successfully saved the training
      Navigator.of(context).pop();
    } catch (e) {
      // Catch any errors during the Firestore operation
      print('Error saving training to Firestore: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save training')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.4,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Dodaj trening'),
            const SizedBox(
              height: 15,
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ListTile(
                      title: Text(start == null
                          ? 'Početak treninga'
                          : 'Početak: ${DateFormat('dd.MM.yyyy HH:mm').format(start!)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? pickedDate = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2023),
                            lastDate: DateTime(2100),
                            initialDate: DateTime.now());
                        if (pickedDate != null) {
                          final TimeOfDay? pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (pickedTime != null) {
                            setState(() {
                              start = DateTime(
                                  pickedDate.year,
                                  pickedDate.month,
                                  pickedDate.day,
                                  pickedTime.hour,
                                  pickedTime.minute);
                            });
                          }
                        }
                      },
                    ),
                    ListTile(
                      title: Text(end == null
                          ? 'Završetak treninga'
                          : 'Kraj: ${DateFormat('dd.MM.yyyy HH:mm').format(end!)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? pickedDate = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2023),
                            lastDate: DateTime(2100),
                            initialDate: DateTime.now());
                        if (pickedDate != null) {
                          final TimeOfDay? pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (pickedTime != null) {
                            setState(() {
                              end = DateTime(
                                  pickedDate.year,
                                  pickedDate.month,
                                  pickedDate.day,
                                  pickedTime.hour,
                                  pickedTime.minute);
                            });
                          }
                        }
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DropdownButton<String>(
                          value: dropdownValue,
                          onChanged: (String? newValue) {
                            setState(() {
                              dropdownValue = newValue!;
                            });
                          },
                          items: <String>[
                            'OŠ Ljubo Babić - dvorana',
                            'OŠ Ljubo Babić - igralište',
                            'Centar za kulturu',
                            'Kino',
                            'SŠ Jastrebarsko - velika dvorana',
                            'SŠ Jastrebarsko - mala dvorana'
                          ].map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        await saveTrainingToFirestore();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(15.0),
                        decoration: BoxDecoration(
                          borderRadius:
                              const BorderRadius.all(Radius.circular(15.0)),
                          color: Colors.purple,
                          border: Border.all(color: Colors.purple, width: 2),
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
                            Icon(Icons.check, color: Colors.white),
                            Text(
                              'Dodaj trening',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
