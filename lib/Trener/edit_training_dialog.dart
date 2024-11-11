import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EditTrainingDialog extends StatefulWidget {
  final String teamName;
  final String monthYear;
  final String docId;
  final Function(Map<String, dynamic>) onUpdate;

  const EditTrainingDialog({
    Key? key,
    required this.teamName,
    required this.monthYear,
    required this.docId,
    required this.onUpdate,
  }) : super(key: key);

  @override
  State<EditTrainingDialog> createState() => _EditTrainingDialogState();
}

class _EditTrainingDialogState extends State<EditTrainingDialog> {
  String dropdownValue = 'OŠ Ljubo Babić - dvorana';
  DateTime? start;
  DateTime? end;

  @override
  void initState() {
    super.initState();
    _fetchExistingData();
  }

  Future<void> _fetchExistingData() async {
    try {
      // Update path to include teamName and monthYear
      DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
          .collection('Clanica_Tim_Trening_2')
          .doc(widget.teamName)
          .collection(widget.monthYear)
          .doc(widget.docId)
          .get();

      if (docSnapshot.exists) {
        var data = docSnapshot.data() as Map<String, dynamic>;

        setState(() {
          if (data['Početak'] != null) {
            start = (data['Početak'] as Timestamp).toDate();
          }
          if (data['Kraj'] != null) {
            end = (data['Kraj'] as Timestamp).toDate();
          }
          if (data['Mjesto'] != null) {
            dropdownValue = data['Mjesto'];
          }
        });
      }
    } catch (e) {
      print('Error fetching existing data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(builder: (context, setState) {
      return AlertDialog(
        title: const Text('Uredi podatke treninga'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
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
                  'SŠ Jastrebarsko - v. dvorana',
                  'SŠ Jastrebarsko - m. dvorana'
                ].map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              ListTile(
                title: Text(start == null
                    ? 'Početak treninga'
                    : 'Početak: ${DateFormat('dd.MM.yyyy HH:mm').format(start!)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: start ?? DateTime.now(),
                    firstDate: DateTime(2022),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    final TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime:
                          TimeOfDay.fromDateTime(start ?? DateTime.now()),
                    );
                    if (pickedTime != null) {
                      setState(() {
                        start = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    }
                  }
                },
              ),
              ListTile(
                title: Text(end == null
                    ? 'Završetak treninga'
                    : 'Završetak: ${DateFormat('dd.MM.yyyy HH:mm').format(end!)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: end ?? DateTime.now(),
                    firstDate: DateTime(2022),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    final TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime:
                          TimeOfDay.fromDateTime(end ?? DateTime.now()),
                    );
                    if (pickedTime != null) {
                      setState(() {
                        end = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    }
                  }
                },
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Odustani'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('Spremi'),
            onPressed: () async {
              if (dropdownValue.isNotEmpty) {
                try {
                  Map<String, dynamic> updateData = {'Mjesto': dropdownValue};

                  if (start != null && end != null) {
                    updateData['Početak'] = Timestamp.fromDate(start!);
                    updateData['Kraj'] = Timestamp.fromDate(end!);
                  }

                  // Update path to include teamName and monthYear
                  await FirebaseFirestore.instance
                      .collection('Clanica_Tim_Trening_2')
                      .doc(widget.teamName)
                      .collection(widget.monthYear)
                      .doc(widget.docId)
                      .update(updateData);

                  widget.onUpdate(updateData);
                  Navigator.of(context).pop();
                } catch (e) {
                  print('Error updating document: $e');
                }
              }
            },
          ),
        ],
      );
    });
  }
}
