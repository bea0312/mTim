import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AddStatusDialog extends StatefulWidget {
  final String docId;

  const AddStatusDialog({super.key, required this.docId});

  @override
  State<AddStatusDialog> createState() => _AddStatusDialogState();
}

class _AddStatusDialogState extends State<AddStatusDialog> {
  String dropdownValue = 'Prisutna';
  DateTime? dolazakTime;
  DateTime? odlazakTime;

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Text('Dodaj dolaznost'),
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
                items: <String>['Prisutna', 'Odsutna']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              if (dropdownValue == 'Prisutna') ...[
                ListTile(
                  title: Text(dolazakTime == null
                      ? 'Odaberite dolazak'
                      : 'Dolazak: ${DateFormat('dd.MM.yyyy HH:mm').format(dolazakTime!)}'),
                  trailing: Icon(Icons.calendar_today),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101),
                    );
                    if (picked != null) {
                      final TimeOfDay? time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        setState(() {
                          dolazakTime = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                ),
                ListTile(
                  title: Text(odlazakTime == null
                      ? 'Odaberite odlazak'
                      : 'Odlazak: ${DateFormat('dd.MM.yyyy HH:mm').format(odlazakTime!)}'),
                  trailing: Icon(Icons.calendar_today),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101),
                    );
                    if (picked != null) {
                      final TimeOfDay? time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        setState(() {
                          odlazakTime = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            time.hour,
                            time.minute,
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
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Add'),
              onPressed: () async {
                if (dropdownValue.isNotEmpty) {
                  Map<String, dynamic> updateData = {'Status': dropdownValue};
                  if (dropdownValue == 'Prisutna' &&
                      dolazakTime != null &&
                      odlazakTime != null) {
                    updateData['Dolazak'] = Timestamp.fromDate(dolazakTime!);
                    updateData['Odlazak'] = Timestamp.fromDate(odlazakTime!);
                  }
                  await FirebaseFirestore.instance
                      .collection('Clanica_Tim_Trening')
                      .doc(widget.docId)
                      .update(updateData);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }
}