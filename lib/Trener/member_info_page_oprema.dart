import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mtim/Trener/add_status_oprema_dialog.dart';
import 'package:nfc_manager/nfc_manager.dart';

class MemberInfoPageOprema extends StatefulWidget {
  final String docId;
  MemberInfoPageOprema({super.key, required this.docId});
  @override
  State<MemberInfoPageOprema> createState() => MemberInfoPageOpremaState();
}

class MemberInfoPageOpremaState extends State<MemberInfoPageOprema> {
  List<Map<String, dynamic>> things = [];
  @override
  void initState() {
    super.initState();
    _getAllThingsForTheMember();
  }

  String? opremaUID;

  Future<void> _getAllThingsForTheMember() async {
    try {
      QuerySnapshot clanicaOpremaSnapshot = await FirebaseFirestore.instance
          .collection('Clanica_Oprema')
          .where('ClanicaUID', isEqualTo: widget.docId)
          .get();

      if (clanicaOpremaSnapshot.docs.isEmpty) {
        setState(() {
          things = [];
        });
        return;
      }

      List<Map<String, dynamic>> equipmentData = [];
      for (var doc in clanicaOpremaSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        var opremaId = data['OpremaUID'];
        opremaUID = opremaId;

        if (data['Vracanje'] != null) {
          continue;
        }

        DocumentSnapshot opremaSnapshot = await FirebaseFirestore.instance
            .collection('Oprema')
            .doc(opremaId)
            .get();

        if (!opremaSnapshot.exists) {
          continue;
        }

        var opremaData = opremaSnapshot.data() as Map<String, dynamic>;
        var naziv = opremaData['Naziv'] ?? 'Unknown';
        var velicina = opremaData['Veličina'] ?? 'Unknown';

        var membersWithSameOprema =
            await _getMembersWithSameEquipment(opremaId);

        equipmentData.add({
          'ClanicaUID': data['ClanicaUID'],
          'Status': data['Status'] ?? 'N/A',
          'Naziv': naziv,
          'Veličina': velicina,
          'Preuzimanje': data['Preuzimanje'] != null
              ? _formatDateOnly(data['Preuzimanje'])
              : 'N/A',
          'Vracanje': data['Vracanje'] != null
              ? _formatDateOnly(data['Vracanje'])
              : 'N/A',
          'MembersWithSameOprema': membersWithSameOprema,
          'DocumentID': doc.id,
          'PreuzimanjeTimestamp':
              data['Preuzimanje'] as Timestamp? ?? Timestamp.now(),
        });
      }

      equipmentData.sort((a, b) =>
          b['PreuzimanjeTimestamp'].compareTo(a['PreuzimanjeTimestamp']));

      setState(() {
        things = equipmentData;
      });
    } catch (e) {
      print('Error retrieving things: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _getMembersWithSameEquipment(
      String opremaId) async {
    try {
      QuerySnapshot membersSnapshot = await FirebaseFirestore.instance
          .collection('Clanica_Oprema')
          .where('OpremaUID', isEqualTo: opremaId)
          .get();

      List<Map<String, dynamic>> membersData = [];
      for (var doc in membersSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;

        DocumentSnapshot memberSnapshot = await FirebaseFirestore.instance
            .collection('Clanica')
            .doc(data['ClanicaUID'])
            .get();

        if (!memberSnapshot.exists) {
          continue;
        }

        var memberData = memberSnapshot.data() as Map<String, dynamic>;
        var memberName = memberData['Ime'] ?? 'Unknown';
        var memberSurname = memberData['Prezime'] ?? 'Unknown';

        membersData.add({
          'Ime': memberName,
          'Prezime': memberSurname,
          'Preuzimanje': data['Preuzimanje'] != null
              ? _formatDateOnly(data['Preuzimanje'])
              : 'N/A',
          'Vracanje': data['Vracanje'] != null
              ? _formatDateOnly(data['Vracanje'])
              : 'N/A',
          'ClanicaUID': data['ClanicaUID'] ?? '',
          'PreuzimanjeTimestamp':
              data['Preuzimanje'] as Timestamp? ?? Timestamp.now(),
        });
      }

      membersData.sort((a, b) =>
          b['PreuzimanjeTimestamp'].compareTo(a['PreuzimanjeTimestamp']));

      return membersData;
    } catch (e) {
      print('Error retrieving members with same equipment: $e');
      return [];
    }
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
        return AddStatusOpremaDialog(
          docId: docId,
          onUpdate: (updatedData) {
            setState(() {
              for (var thing in things) {
                if (thing['DocumentID'] == docId) {
                  thing['Status'] = updatedData['Status'] ?? thing['Status'];
                  if (updatedData['Preuzimanje'] != null) {
                    thing['Preuzimanje'] =
                        _formatDateOnly(updatedData['Preuzimanje']);
                  }
                  if (updatedData['Vracanje'] != null) {
                    thing['Vracanje'] =
                        _formatDateOnly(updatedData['Vracanje']);
                  }
                }
              }
            });
          },
        );
      },
    );
  }

  Future<bool> _checkEquipmentAvailability(String opremaId) async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('Clanica_Oprema')
        .where('OpremaUID', isEqualTo: opremaId)
        .get();

    if (snapshot.docs.isEmpty) {
      return true;
    }

    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      var vracanje = data['Vracanje'];

      if (vracanje == null ||
          (vracanje as Timestamp).toDate().isAfter(DateTime.now())) {
        return false;
      }
    }

    return true;
  }

  void _readNfcTag() {
    NfcManager.instance.startSession(onDiscovered: (NfcTag badge) async {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('NFC scanning started.')),
      );
      try {
        var ndef = Ndef.from(badge);

        if (ndef != null && ndef.cachedMessage != null) {
          String tempRecord = "";
          for (var record in ndef.cachedMessage!.records) {
            tempRecord =
                "${String.fromCharCodes(record.payload.sublist(record.payload[0] + 1))}";
            print(tempRecord);

            bool isAvailable = await _checkEquipmentAvailability(tempRecord);
            if (isAvailable) {
              await FirebaseFirestore.instance
                  .collection('Clanica_Oprema')
                  .add({
                'ClanicaUID': widget.docId,
                'OpremaUID': tempRecord,
                'Preuzimanje': Timestamp.now(),
                'Status': 'Uredno',
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Equipment assigned successfully!')),
              );
              _getAllThingsForTheMember();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('This equipment is not available.')),
              );
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No NDEF data found on the NFC tag.')),
          );
        }
      } catch (e) {
        print('Error processing NFC tag: $e');
      } finally {
        NfcManager.instance.stopSession();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('NFC scanning stopped.')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Dodijeli opremu'),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () {
                _readNfcTag();
              },
            ),
          ],
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: things.isEmpty
          ? const Center(child: Text('Nema dodijeljene opreme'))
          : ListView.builder(
              itemCount: things.length,
              itemBuilder: (context, index) {
                Map<String, dynamic> thing = things[index];
                List<Map<String, dynamic>> membersWithSameOprema =
                    thing['MembersWithSameOprema'] ?? [];

                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: Colors.purple[100],
                      borderRadius:
                          const BorderRadius.all(Radius.circular(15.0)),
                    ),
                    child: ExpansionTile(
                      title: Text(
                        '${thing['Naziv']} (${thing['Veličina']})',
                        style: const TextStyle(fontSize: 20),
                      ),
                      children: membersWithSameOprema.map((member) {
                        return ListTile(
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${member['Ime']} ${member['Prezime']}'),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () {
                                      final docId =
                                          thing['DocumentID'] as String?;
                                      if (docId != null && docId.isNotEmpty) {
                                        _showAddStatusDialog(context, docId);
                                        _getAllThingsForTheMember();
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.arrow_circle_left_outlined),
                                    onPressed: () async {
                                      final docId =
                                          thing['DocumentID'] as String?;
                                      if (docId != null && docId.isNotEmpty) {
                                        await FirebaseFirestore.instance
                                            .collection('Clanica_Oprema')
                                            .doc(docId)
                                            .update({
                                          'Vracanje': Timestamp.now(),
                                        });

                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Equipment returned successfully!')),
                                        );

                                        _getAllThingsForTheMember();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Preuzimanje: ${member['Preuzimanje']} - Vracanje: ${member['Vracanje']}'),
                              Text('Status: ${thing['Status']}')
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
