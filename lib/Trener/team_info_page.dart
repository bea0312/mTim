import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mtim/Trener/add_new_member_dialog.dart';
/*import 'package:excel/excel.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/foundation.dart';*/

class TeamInfoPage extends StatefulWidget {
  const TeamInfoPage({super.key});

  @override
  State<TeamInfoPage> createState() => _TeamInfoPageState();
}

class _TeamInfoPageState extends State<TeamInfoPage> {
  String? userTim;
  String? userAgeClass;
  bool isLoading = true;
  int numberOfMembers = 0;
  int numOfMembersOutOfAgeGroup = 0;

  @override
  void initState() {
    super.initState();
    fetchUserTim().then((_) {
      print('fetchUserTim completed and _getTeamData called');
    });
  }

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
              if (mounted) {
                setState(() {
                  userTim = userData['Tim'];
                  userAgeClass = userData['Dobni razred'];
                });
                print('Fetched userTim: $userTim');
              }
              await _getTeamData();
              print('Called _getTeamData');
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
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _getTeamData() async {
    if (userTim == null) {
      print('userTim is null in _getTeamData');
      return;
    }

    try {
      print('Fetching team data for: $userTim');
      QuerySnapshot teamMembersSnapshot = await FirebaseFirestore.instance
          .collection('Clanica')
          .where('Tim', isEqualTo: userTim)
          .get();

      List<QueryDocumentSnapshot> teamMembers =
          teamMembersSnapshot.docs.where((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return data.containsKey('Uloga') && data['Uloga'] != 'Trener';
      }).toList();

      List<QueryDocumentSnapshot> outTeamMembers = teamMembers.where((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return data.containsKey('Dobni razred') &&
            data['Dobni razred'] != userAgeClass;
      }).toList();

      print('All team members: ${teamMembersSnapshot.docs.length}');
      print('Filtered team members: ${teamMembers.length}');

      if (mounted) {
        setState(() {
          numberOfMembers = teamMembers.length;
          numOfMembersOutOfAgeGroup = outTeamMembers.length;
        });
      }
    } catch (e) {
      print('Error fetching team data: $e');
    }
  }

  void _addNewMember(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddNewMemberDialog(
          team: userTim,
        );
      },
    );
  }

  /*void openExcelFile(String filePath) {
    if (Platform.isAndroid || Platform.isIOS) {
      OpenFile.open(filePath);
    } else {
      // Handle other platforms or show an error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('This platform is not supported for opening files.')),
      );
    }
  }

  void exportExcel(BuildContext context) async {
    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet()!];
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1)).value =
        'proba';

    final fileBytes = excel.save();
    if (fileBytes != null) {
      final directory = await getApplicationDocumentsDirectory();
      final outputPath = "${directory.path}/proba.xlsx";
      final outputFile = File(outputPath);

      await outputFile.writeAsBytes(fileBytes);

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('File Saved'),
            content: Text(
                'The file has been saved successfully. Do you want to open it?'),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text('Open'),
                onPressed: () {
                  Navigator.of(context).pop();
                  // Open the file using the openFile function
                  openExcelFile(outputPath);
                },
              ),
            ],
          );
        },
      );
    }
  }*/

  double _percentageOutOfAgeGroup() {
    return (numOfMembersOutOfAgeGroup / numberOfMembers) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    double percentageOutOfAgeGroup = _percentageOutOfAgeGroup();

    return Scaffold(
      body: Center(
        child: Container(
          width: screenWidth * 0.9,
          height: screenHeight * 0.65,
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
                children: [
                  Column(
                    children: [
                      Text('Broj članica'),
                      Text(
                        '$numberOfMembers',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      )
                    ],
                  ),
                  Divider(
                    color: Colors.purple,
                    thickness: 2,
                    indent: 0,
                    endIndent: 16,
                  ),
                  Column(
                    children: [
                      Text('Izvan dobnog razreda'),
                      Text(
                        '$numOfMembersOutOfAgeGroup',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      )
                    ],
                  ),
                  const Divider(
                    color: Colors.purple,
                    thickness: 2,
                    indent: 0,
                    endIndent: 16,
                  ),
                  Column(
                    children: [
                      Text('Postotak izvan dobnog rareda'),
                      Text(
                        '${percentageOutOfAgeGroup.toStringAsFixed(1)}%',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      )
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: screenHeight * 0.2),
                    child: Column(
                      children: [
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              _addNewMember(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.all(
                                    Radius.circular(15.0)),
                                color: Colors.white,
                                border:
                                    Border.all(color: Colors.purple, width: 2),
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
                                  Icon(Icons.add_circle_outline,
                                      color: Colors.purple),
                                  Text(
                                    ' Dodaj članicu',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  /*IconButton(
                      onPressed: () {
                        exportExcel(context);
                      },
                      icon: const Icon(Icons.download_for_offline_outlined))*/
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
