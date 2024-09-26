import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class NewTeamDialog extends StatefulWidget {
  final String docId;
  final String currentTeam;

  const NewTeamDialog(
      {super.key, required this.docId, required this.currentTeam});

  @override
  State<NewTeamDialog> createState() => _NewTeamDialogState();
}

class _NewTeamDialogState extends State<NewTeamDialog> {
  List<String> teamNames = [];
  String? selectedTeam;

  Future<void> _getTeams() async {
    try {
      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('Tim').get();
      List<String> names =
          querySnapshot.docs.map((doc) => doc['Naziv'] as String).toList();

      setState(() {
        teamNames = names;
        selectedTeam = widget.currentTeam;
      });

      print(teamNames);
    } catch (e) {
      print('Error getting teams: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _getTeams();
  }

  Future<void> _saveChange() async {
    try {
      await FirebaseFirestore.instance
          .collection('Clanica')
          .doc(widget.docId)
          .update({'Tim': selectedTeam});

      print('Updated team selection: $selectedTeam');
      Navigator.of(context).pop();
    } catch (e) {
      print('Error updating team selection: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Odaberite tim/dobni razred',
              style: TextStyle(
                  color: Colors.purple,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: teamNames.length,
                itemBuilder: (context, index) {
                  String team = teamNames[index];
                  return RadioListTile<String>(
                    title: Text(team),
                    value: team,
                    groupValue: selectedTeam,
                    onChanged: (String? value) {
                      setState(() {
                        selectedTeam = value;
                      });
                    },
                  );
                },
              ),
            ),
            GestureDetector(
              onTap: _saveChange,
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(15.0)),
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
                      'Spremi odabir',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
