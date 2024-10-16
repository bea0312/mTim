import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MemberInfoPageClanarina extends StatefulWidget {
  final String docId;
  final Function(bool) onOverdueStatusChanged;

  const MemberInfoPageClanarina({
    super.key,
    required this.docId,
    required this.onOverdueStatusChanged,
  });

  @override
  State<MemberInfoPageClanarina> createState() =>
      _MemberInfoPageClanarinaState();
}

class _MemberInfoPageClanarinaState extends State<MemberInfoPageClanarina> {
  List<Map<String, dynamic>> clanarinas = [];
  bool hasOverduePayment = false;
  String cijenaClanarine = '25';

  @override
  void initState() {
    super.initState();
    _checkAndCreateClanarinaForCurrentMonth();
    _getAllClanarina();
  }

  Future<void> _checkAndCreateClanarinaForCurrentMonth() async {
    try {
      String currentRazdoblje =
          "${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}";

      QuerySnapshot clanarinaSnapshot = await FirebaseFirestore.instance
          .collection('Clanarina')
          .where('Razdoblje', isEqualTo: currentRazdoblje)
          .orderBy('Razdoblje', descending: true)
          .get();
      if (clanarinaSnapshot.docs.isEmpty) {
        DocumentReference clanarinaDocRef =
            await FirebaseFirestore.instance.collection('Clanarina').add({
          'Razdoblje': currentRazdoblje,
        });
        QuerySnapshot membersSnapshot =
            await FirebaseFirestore.instance.collection('Clanica').get();
        for (var memberDoc in membersSnapshot.docs) {
          var memberData = memberDoc.data() as Map<String, dynamic>;
          String cijenaClanarine =
              memberData['CijenaClanarine']?.toString() ?? '25';
          await FirebaseFirestore.instance.collection('Clanica_Clanarina').add({
            'ClanicaUID': memberDoc.id,
            'ClanarinaUID': clanarinaDocRef.id,
            'Cijena': cijenaClanarine,
            'Status': 'U čekanju',
            'DatumPlacanja': null,
          });
        }
      }
    } catch (e) {
      print('Error creating Clanarina for current month: $e');
    }
  }

  Future<void> _getAllClanarina() async {
    try {
      QuerySnapshot clanicaClanarinaSnapshot = await FirebaseFirestore.instance
          .collection('Clanica_Clanarina')
          .where('ClanicaUID', isEqualTo: widget.docId)
          .get();

      if (clanicaClanarinaSnapshot.docs.isEmpty) {
        print('No documents found for ClanicaUID: ${widget.docId}');
        return;
      }

      List<Map<String, dynamic>> clanarinasData = [];
      bool overdueFound = false;

      for (var doc in clanicaClanarinaSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        var clanarinaId = data['ClanarinaUID'];

        DocumentSnapshot clanarinaSnapshot = await FirebaseFirestore.instance
            .collection('Clanarina')
            .doc(clanarinaId)
            .get();

        if (!clanarinaSnapshot.exists) {
          print('No Clanarina document found with ID: $clanarinaId');
          continue;
        }

        var clanarinaData = clanarinaSnapshot.data() as Map<String, dynamic>;

        bool isOverdue = _checkIfOverdue(
          clanarinaData['Razdoblje'],
          data['Status'],
        );

        if (isOverdue) {
          overdueFound = true;
        }

        clanarinasData.add({
          'DocId': doc.id,
          'Razdoblje': clanarinaData['Razdoblje'],
          'Cijena': data['Cijena'],
          'Status': data['Status'],
          'DatumPlacanja': data['DatumPlacanja'],
          'IsOverdue': isOverdue,
        });
      }
      clanarinasData.sort((a, b) {
        DateFormat dateFormat = DateFormat('MM/yyyy');
        DateTime dateA = dateFormat.parse(a['Razdoblje']);
        DateTime dateB = dateFormat.parse(b['Razdoblje']);
        return dateB.compareTo(dateA);
      });

      setState(() {
        clanarinas = clanarinasData;
        hasOverduePayment = overdueFound;
      });

      widget.onOverdueStatusChanged(overdueFound);
    } catch (e) {
      print(e);
    }
  }

  bool _checkIfOverdue(String razdoblje, String status) {
    if (status == 'Plaćeno') return false;

    DateTime now = DateTime.now();
    DateFormat dateFormat = DateFormat('MM/yyyy');
    DateTime clanarinaDate = dateFormat.parse(razdoblje);

    DateTime deadline =
        DateTime(clanarinaDate.year, clanarinaDate.month + 1, 15);

    return now.isAfter(deadline);
  }

  Future<void> _updateStatusAndDate(String docId, bool newValue) async {
    try {
      String newStatus = newValue ? 'Plaćeno' : 'U čekanju';
      Timestamp? newDatumPlacanja = newValue ? Timestamp.now() : null;

      await FirebaseFirestore.instance
          .collection('Clanica_Clanarina')
          .doc(docId)
          .update({
        'Status': newStatus,
        'DatumPlacanja': newDatumPlacanja,
      });

      print(
          'Updated Status to $newStatus with DatumPlacanja: $newDatumPlacanja');

      _getAllClanarina();
    } catch (e) {
      print('Error updating status and date: $e');
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    DateTime date = timestamp.toDate();
    return DateFormat('dd-MM-yyyy, HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: clanarinas.isEmpty
          ? const Center(child: Text('No clanarinas found'))
          : ListView.builder(
              itemCount: clanarinas.length,
              itemBuilder: (context, index) {
                var clanarina = clanarinas[index];
                bool isPaid = clanarina['Status'] == 'Plaćeno';

                return Card(
                  color: clanarina['IsOverdue']
                      ? Colors.red[100]
                      : Colors.purple[100],
                  child: ListTile(
                    title: Text(
                      ' ${clanarina['Razdoblje']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cijena: ${clanarina['Cijena']}€'),
                        Text('Status: ${clanarina['Status']}'),
                        Text(
                            'Datum plaćanja: ${_formatDate(clanarina['DatumPlacanja'])}'),
                      ],
                    ),
                    trailing: Checkbox(
                      value: isPaid,
                      onChanged: isPaid
                          ? null
                          : (bool? value) {
                              if (value != null) {
                                _updateStatusAndDate(clanarina['DocId'], value);
                              }
                            },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
