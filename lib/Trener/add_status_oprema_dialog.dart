import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AddStatusOpremaDialog extends StatefulWidget {
  final String docId;
  final Function(Map<String, dynamic>) onUpdate;

  const AddStatusOpremaDialog({
    super.key,
    required this.docId,
    required this.onUpdate,
  });

  @override
  State<AddStatusOpremaDialog> createState() => _AddStatusOpremaDialogState();
}

class _AddStatusOpremaDialogState extends State<AddStatusOpremaDialog> {
  String dropdownValue = 'Uredno';
  DateTime? preuzimanjeTime;
  DateTime? vracanjeTime;

  @override
  void initState() {
    super.initState();
    _fetchExistingData();
  }

  Future<void> _fetchExistingData() async {
    try {
      DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
          .collection('Clanica_Oprema')
          .doc(widget.docId)
          .get();

      if (docSnapshot.exists) {
        var data = docSnapshot.data() as Map<String, dynamic>;

        setState(() {
          if (data['Preuzimanje'] != null) {
            preuzimanjeTime = (data['Preuzimanje'] as Timestamp).toDate();
          }
          if (data['Vracanje'] != null) {
            vracanjeTime = (data['Vracanje'] as Timestamp).toDate();
          }
          if (data['Status'] != null) {
            dropdownValue = data['Status'];
          }
        });
      }
    } catch (e) {
      print('Error fetching existing data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Text('Dodaj status opreme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: dropdownValue,
                onChanged: (String? newValue) {
                  setState(() {
                    dropdownValue = newValue!;
                  });
                },
                items: <String>['Novo', 'Uredno', 'Neuredno']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              if (dropdownValue == 'Uredno') ...[
                ListTile(
                  title: Text(preuzimanjeTime == null
                      ? 'Odaberite preuzimanje'
                      : 'Preuzimanje: ${DateFormat('dd.MM.yyyy HH:mm').format(preuzimanjeTime!)}'),
                  trailing: Icon(Icons.calendar_today),
                  onTap: () async {
                    final DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: preuzimanjeTime ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101),
                    );
                    if (pickedDate != null) {
                      final TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(
                            preuzimanjeTime ?? DateTime.now()),
                      );
                      if (pickedTime != null) {
                        setState(() {
                          preuzimanjeTime = DateTime(
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
                  title: Text(vracanjeTime == null
                      ? 'Odaberite vracanje'
                      : 'Vracanje: ${DateFormat('dd.MM.yyyy HH:mm').format(vracanjeTime!)}'),
                  trailing: Icon(Icons.calendar_today),
                  onTap: () async {
                    final DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: vracanjeTime ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101),
                    );
                    if (pickedDate != null) {
                      final TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(
                            vracanjeTime ?? DateTime.now()),
                      );
                      if (pickedTime != null) {
                        setState(() {
                          vracanjeTime = DateTime(
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
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Odustani'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Dodaj'),
              onPressed: () async {
                if (dropdownValue.isNotEmpty) {
                  try {
                    DocumentSnapshot docSnapshot = await FirebaseFirestore
                        .instance
                        .collection('Clanica_Oprema')
                        .doc(widget.docId)
                        .get();

                    if (docSnapshot.exists) {
                      Map<String, dynamic> updateData = {
                        'Status': dropdownValue
                      };

                      if (dropdownValue == 'Uredno' &&
                          preuzimanjeTime != null &&
                          vracanjeTime != null) {
                        updateData['Preuzimanje'] =
                            Timestamp.fromDate(preuzimanjeTime!);
                        updateData['Vracanje'] =
                            Timestamp.fromDate(vracanjeTime!);
                      }

                      await FirebaseFirestore.instance
                          .collection('Clanica_Oprema')
                          .doc(widget.docId)
                          .update(updateData);

                      widget.onUpdate(updateData);

                      Navigator.of(context).pop();
                    } else {
                      print('Document does not exist');
                    }
                  } catch (e) {
                    print('Error updating document: $e');
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
}
