import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
    final newTraining = {
      'Početak': start,
      'Kraj': end,
      'Mjesto': dropdownValue,
      'Tim': widget.team,
      'Status': 'U budućnosti'
    };

    DocumentReference trainingRef = await FirebaseFirestore.instance
        .collection('Tim_Trening')
        .add(newTraining);
    Navigator.of(context).pop();

    trainingID = trainingRef.id;

    QuerySnapshot membersSnapshot = await FirebaseFirestore.instance
        .collection('Clanica')
        .where('Tim', isEqualTo: widget.team)
        .get();

    for (var memberDoc in membersSnapshot.docs) {
      memberId = memberDoc.id;

      final data = {'ClanicaUID': memberId, 'Tim_TreningUID': trainingID};
      await FirebaseFirestore.instance
          .collection('Clanica_Tim_Trening')
          .add(data);
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
                child: Column(
              children: [
                ListTile(
                  title: const Text('Datum i vrijeme početka'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final DateTime? pickedDate = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2023),
                        lastDate: DateTime(2100));
                    if (pickedDate != null) {
                      final TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(DateTime.now()),
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
                  title: const Text('Datum i vrijeme završetka'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final DateTime? pickedDate = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2023),
                        lastDate: DateTime(2100));
                    if (pickedDate != null) {
                      final TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(DateTime.now()),
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
                GestureDetector(
                  onTap: saveTrainingToFirestore,
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
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ))
          ],
        ),
      ),
    );
  }
}