import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mtim/Trener/choose_new_team_dialog.dart';
import 'package:mtim/Trener/member_info_page_dolasci.dart';
import 'package:mtim/Trener/member_info_page_oprema.dart';
import 'member_info_page_clanarina.dart';

class MemberInfoPage extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> memberData;

  const MemberInfoPage({
    super.key,
    required this.docId,
    required this.memberData,
  });

  @override
  State<MemberInfoPage> createState() => _MemberInfoPageState();
}

class _MemberInfoPageState extends State<MemberInfoPage> {
  late bool gdprValue;
  bool hasOverduePayments = false;
  TextEditingController brojIskazniceController = TextEditingController();
  TextEditingController godinaPreregistracijeController =
      TextEditingController();
  String dropdownValue = 'Dječji sastav';

  @override
  void initState() {
    super.initState();
    dropdownValue = widget.memberData['Dobni razred'] ?? 'Dječji sastav';
    gdprValue = widget.memberData['GDPR'] ?? false;
    _checkForOverduePayments();
    brojIskazniceController.text = widget.memberData['Broj iskaznice'] ?? '';
    godinaPreregistracijeController.text =
        widget.memberData['Godina preregistracije'] ?? '';
  }

  @override
  void dispose() {
    brojIskazniceController.dispose();
    godinaPreregistracijeController.dispose();
    super.dispose();
  }

  Future<void> _updateBrojIskaznice(String newValue) async {
    try {
      await FirebaseFirestore.instance
          .collection('Clanica')
          .doc(widget.docId)
          .update({'Broj iskaznice': newValue});
      print('Broj iskaznice updated: $newValue');
    } catch (e) {
      print('Error updating Broj iskaznice: $e');
    }
  }

  Future<void> _updateGodinaPreregistracije(String newValue) async {
    try {
      await FirebaseFirestore.instance
          .collection('Clanica')
          .doc(widget.docId)
          .update({'Godina preregistracije': newValue});
      print('Godina preregistracije updated: $newValue');
    } catch (e) {
      print('Error updating Godina preregistracije: $e');
    }
  }

  Future<void> _updateDobniRazred(String newValue) async {
    try {
      String? memberId = widget.docId;
      await FirebaseFirestore.instance
          .collection('Clanica')
          .doc(memberId)
          .update({'Dobni razred': newValue});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dobni razred updated successfully')),
      );
    } catch (e) {
      print('Error updating member data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update Dobni razred: $e')),
      );
    }
  }

  void onChanged(bool? newValue) {
    setState(() {
      gdprValue = newValue ?? false;
    });
    updateDatabase(newValue);
  }

  Future<void> updateDatabase(bool? newValue) async {
    try {
      await FirebaseFirestore.instance
          .collection('Clanica')
          .doc(widget.docId)
          .update({'GDPR': newValue});
      print('Updated GDPR value in database: $newValue');
    } catch (e) {
      print('Error updating GDPR value: $e');
    }
  }

  Future<void> _checkForOverduePayments() async {
    try {
      QuerySnapshot clanicaClanarinaSnapshot = await FirebaseFirestore.instance
          .collection('Clanica_Clanarina')
          .where('ClanicaUID', isEqualTo: widget.docId)
          .get();

      if (clanicaClanarinaSnapshot.docs.isEmpty) {
        print('No documents found for ClanicaUID: ${widget.docId}');
        return;
      }

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
        bool isOverdue = _isOverdue(clanarinaData['Razdoblje'], data['Status']);

        if (isOverdue) {
          overdueFound = true;
          break;
        }
      }

      setState(() {
        hasOverduePayments = overdueFound;
      });
    } catch (e) {
      print('Error checking for overdue payments: $e');
    }
  }

  bool _isOverdue(String razdoblje, String status) {
    if (status == 'Plaćeno') return false;

    DateTime lastDayOfMonth = DateFormat("MM/yyyy").parse(razdoblje);
    lastDayOfMonth = DateTime(lastDayOfMonth.year, lastDayOfMonth.month + 1, 0);
    DateTime dueDate = lastDayOfMonth.add(const Duration(days: 15));

    return DateTime.now().isAfter(dueDate);
  }

  void _onOverdueStatusChanged(bool isOverdue) {
    setState(() {
      hasOverduePayments = isOverdue;
    });
  }

  void _chooseNewTeam(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return NewTeamDialog(
          docId: widget.docId,
          currentTeam: widget.memberData['Tim'] ?? '',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(157, 173, 24, 199),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Center(
            child: Text(
              '${widget.memberData['Ime']} ${widget.memberData['Prezime']}',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
          titleSpacing: 0,
        ),
        body: Column(
          children: [
            SingleChildScrollView(
              child: Center(
                child: Container(
                  width: screenWidth * 0.9,
                  height: screenHeight * 0.20,
                  margin: const EdgeInsets.symmetric(horizontal: 0.0),
                  padding: const EdgeInsets.all(8.0),
                  child: Card(
                    color: Colors.purple[100],
                    margin: const EdgeInsets.symmetric(horizontal: 0.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: SizedBox(
                            width: 100,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'OIB',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.normal),
                                      ),
                                      Text(
                                        '${widget.memberData['OIB']}',
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 20,
                                  ),
                                  const Text(
                                    'Datum rođenja',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                  Text(
                                    '${widget.memberData['Datum rođenja']}',
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ]),
                          ),
                        ),
                        const VerticalDivider(
                          color: Colors.purple,
                          thickness: 2,
                          width: 20,
                          indent: 15,
                          endIndent: 15,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.memberData.containsKey(
                                        'Godina preregistracije') &&
                                    widget.memberData[
                                            'Godina preregistracije'] !=
                                        null)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller:
                                              godinaPreregistracijeController,
                                          decoration: const InputDecoration(
                                            labelText: 'Godina preregistracije',
                                            labelStyle: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.normal,
                                                color: Colors.black),
                                            border: OutlineInputBorder(
                                                borderRadius: BorderRadius.all(
                                                    Radius.circular(15))),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    horizontal: 10.0,
                                                    vertical: 5.0),
                                          ),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          onSubmitted: (value) {
                                            _updateGodinaPreregistracije(value);
                                          },
                                        ),
                                      ),
                                      IconButton(
                                        icon:
                                            const Icon(Icons.save_as_outlined),
                                        onPressed: () {
                                          _updateGodinaPreregistracije(
                                              godinaPreregistracijeController
                                                  .text);

                                          FocusScope.of(context).unfocus();
                                        },
                                      ),
                                    ],
                                  ),
                                const SizedBox(
                                  height: 10,
                                ),
                                if (widget.memberData
                                        .containsKey('Broj iskaznice') &&
                                    widget.memberData['Broj iskaznice'] != null)
                                  Row(children: [
                                    Expanded(
                                      child: TextField(
                                        controller: brojIskazniceController,
                                        decoration: const InputDecoration(
                                          labelText: 'Broj iskaznice',
                                          labelStyle: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.normal,
                                              color: Colors.black),
                                          border: OutlineInputBorder(
                                              borderRadius: BorderRadius.all(
                                                  Radius.circular(15))),
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 10.0, vertical: 5.0),
                                        ),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        onSubmitted: (value) {
                                          _updateBrojIskaznice(value);
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.save_as_outlined),
                                      onPressed: () {
                                        _updateBrojIskaznice(
                                            brojIskazniceController.text);

                                        FocusScope.of(context).unfocus();
                                      },
                                    ),
                                  ])
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            TabBar(
              tabs: [
                const Tab(text: 'Podatci'),
                const Tab(text: 'Dolasci'),
                const Tab(text: 'Oprema'),
                Tab(
                  text: 'Članarina',
                  icon: hasOverduePayments
                      ? const Icon(
                          Icons.warning,
                          color: Colors.red,
                          size: 15,
                        )
                      : null,
                ),
              ],
              indicatorColor: Colors.purple,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  SingleChildScrollView(
                    child: Center(
                      child: Container(
                        width: screenWidth * 0.9,
                        height: screenHeight * 0.60,
                        margin: const EdgeInsets.symmetric(horizontal: 16.0),
                        padding: const EdgeInsets.all(8.0),
                        child: Card(
                          color: Colors.purple[100],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15.0),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Column(
                                  children: [Text('Adresa')],
                                ),
                                Column(
                                  children: [
                                    Text(
                                      '${widget.memberData['Adresa']}',
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const Column(
                                  children: [
                                    Divider(
                                      color: Colors.purple,
                                      thickness: 2,
                                      indent: 0,
                                      endIndent: 16,
                                    ),
                                  ],
                                ),
                                const Column(
                                  children: [Text('Broj mobitela članice')],
                                ),
                                Column(
                                  children: [
                                    Text(
                                      '${widget.memberData['Broj mobitela članice']}',
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const Column(
                                  children: [
                                    Divider(
                                      color: Colors.purple,
                                      thickness: 2,
                                      indent: 0,
                                      endIndent: 16,
                                    ),
                                  ],
                                ),
                                const Column(
                                  children: [Text('Broj mobitela roditelja')],
                                ),
                                Column(
                                  children: [
                                    Text(
                                      '${widget.memberData['Broj mobitela roditelja']}',
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const Column(
                                  children: [
                                    Divider(
                                      color: Colors.purple,
                                      thickness: 2,
                                      indent: 0,
                                      endIndent: 16,
                                    ),
                                  ],
                                ),
                                const Column(
                                  children: [Text('Članica od')],
                                ),
                                Column(
                                  children: [
                                    Text(
                                      '${widget.memberData['Članica od']}',
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const Column(
                                  children: [
                                    Divider(
                                      color: Colors.purple,
                                      thickness: 2,
                                      indent: 0,
                                      endIndent: 16,
                                    ),
                                  ],
                                ),
                                const Column(children: [Text('GDPR')]),
                                Column(
                                  children: [
                                    Checkbox(
                                      value: gdprValue,
                                      onChanged: onChanged,
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Center(
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 5),
                                        child: DropdownButton<String>(
                                          value: dropdownValue,
                                          onChanged: (String? newValue) {
                                            if (newValue != null) {
                                              setState(() {
                                                dropdownValue = newValue;
                                              });
                                              _updateDobniRazred(newValue);
                                            }
                                          },
                                          items: <String>[
                                            'Dječji sastav',
                                            'Kadet',
                                            'Junior',
                                            'Senior',
                                            'Veteran',
                                          ].map<DropdownMenuItem<String>>(
                                              (String value) {
                                            return DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(value),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Center(
                                      child: GestureDetector(
                                        onTap: () {
                                          _chooseNewTeam(context);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(8.0),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                const BorderRadius.all(
                                                    Radius.circular(15.0)),
                                            color: Colors.white,
                                            border: Border.all(
                                                color: Colors.purple, width: 2),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.grey
                                                    .withOpacity(0.5),
                                                spreadRadius: 5,
                                                blurRadius: 7,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.upload_outlined,
                                                  color: Colors.purple),
                                              Text(
                                                'Promijeni tim',
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  MemberInfoPageDolasci(docId: widget.docId),
                  MemberInfoPageOprema(docId: widget.docId),
                  MemberInfoPageClanarina(
                    docId: widget.docId,
                    onOverdueStatusChanged: _onOverdueStatusChanged,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
