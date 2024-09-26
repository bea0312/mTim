import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';

class OpremaPage extends StatefulWidget {
  const OpremaPage({super.key});

  @override
  State<OpremaPage> createState() => _OpremaPageState();
}

class _OpremaPageState extends State<OpremaPage> {
  String temp = "";

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
          'Status': data['Status'] ?? '',
        });
      }

      return membersData;
    } catch (e) {
      print('Error retrieving members with same equipment: $e');
      return [];
    }
  }

  String _formatDateOnly(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return '${date.day}.${date.month}.${date.year}';
  }

  void _scanNfcAndFindTheEquipment() {
    NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('NFC scanning started.')),
      );
      try {
        var ndef = Ndef.from(tag);
        if (ndef != null && ndef.cachedMessage != null) {
          for (var record in ndef.cachedMessage!.records) {
            temp = String.fromCharCodes(
                record.payload.sublist(record.payload[0] + 1));
            print(temp);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Scanned: $temp')),
            );
            setState(() {});
          }
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
    double screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.find_in_page_outlined),
                onPressed: _scanNfcAndFindTheEquipment,
              ),
              const SizedBox(width: 8),
              const Text('Skeniraj i pronađi...'),
            ],
          ),
        ),
      ),
      body: temp.isEmpty
          ? const Center(
              child: Text('Skeniraj NFC tag za informacije o opremi'))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Oprema')
                  .doc(temp)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading equipment.'));
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text('No equipment found.'));
                }

                final equipmentData =
                    snapshot.data!.data() as Map<String, dynamic>;
                final naziv = equipmentData['Naziv'] ?? 'Unknown';
                final velicina = equipmentData['Veličina'] ?? 'Unknown';

                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getMembersWithSameEquipment(temp),
                  builder: (context, historySnapshot) {
                    if (historySnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (historySnapshot.hasError || !historySnapshot.hasData) {
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          height: 50,
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            color: Colors.purple[100],
                            borderRadius:
                                const BorderRadius.all(Radius.circular(15.0)),
                          ),
                          child: SingleChildScrollView(
                            child: ExpansionTile(
                              title: Text(naziv),
                              subtitle: Text('Veličina: $velicina'),
                              children: const [
                                ListTile(
                                  title: Text('Error loading history'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    final membersWithSameOprema = historySnapshot.data!;

                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        height: screenHeight * 0.9,
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: Colors.purple[100],
                          borderRadius:
                              const BorderRadius.all(Radius.circular(15.0)),
                        ),
                        child: SingleChildScrollView(
                          child: ExpansionTile(
                            title: Text(
                              '$naziv ($velicina)',
                              style: const TextStyle(fontSize: 20),
                            ),
                            children: membersWithSameOprema.map((memberData) {
                              return ListTile(
                                title: Text(
                                    '${memberData['Ime']} ${memberData['Prezime']}'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        'Preuzimanje: ${memberData['Preuzimanje']} - Vracanje: ${memberData['Vracanje']}'),
                                    Text('Status: ${memberData['Status']}')
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
