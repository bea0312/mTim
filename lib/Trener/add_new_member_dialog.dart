import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddNewMemberDialog extends StatefulWidget {
  final String? team;
  const AddNewMemberDialog({super.key, required this.team});

  @override
  State<AddNewMemberDialog> createState() => _AddNewMemberDialogState();
}

class _AddNewMemberDialogState extends State<AddNewMemberDialog> {
  TextEditingController imeController = TextEditingController();
  TextEditingController prezimeController = TextEditingController();
  TextEditingController adresaController = TextEditingController();
  TextEditingController mailController = TextEditingController();
  TextEditingController mobRoditeljaController = TextEditingController();
  TextEditingController mobClaniceController = TextEditingController();
  TextEditingController cijenaClanarineController = TextEditingController();
  TextEditingController godinaPreregController = TextEditingController();
  TextEditingController oibController = TextEditingController();
  TextEditingController clanicaOdController = TextEditingController();
  TextEditingController brojIskazniceController = TextEditingController();
  TextEditingController datumRodenjaController = TextEditingController();
  TextEditingController dobniRazredController = TextEditingController();
  String dropdownValue = 'Dječji sastav';

  @override
  void dispose() {
    imeController.dispose();
    prezimeController.dispose();
    adresaController.dispose();
    mailController.dispose();
    mobRoditeljaController.dispose();
    mobClaniceController.dispose();
    cijenaClanarineController.dispose();
    godinaPreregController.dispose();
    oibController.dispose();
    clanicaOdController.dispose();
    brojIskazniceController.dispose();
    datumRodenjaController.dispose();
    dobniRazredController.dispose();
    super.dispose();
  }

  Future<void> saveMemberToFirestore() async {
    final newMember = {
      'Ime': imeController.text,
      'Prezime': prezimeController.text,
      'OIB': oibController.text,
      'Datum rođenja': datumRodenjaController.text,
      'Adresa': adresaController.text,
      'Email': mailController.text,
      'Broj mobitelja roditelja': mobRoditeljaController.text,
      'Broj mobitela članice': mobClaniceController.text,
      'CijenaClanarine': cijenaClanarineController.text,
      'Dobni razred': dropdownValue,
      'Godina preregistracije': godinaPreregController.text,
      'Broj iskaznice': brojIskazniceController.text,
      'Članica od': DateTime.now().year,
      'Tim': widget.team,
      'Uloga': 'Plesač',
      'Status': 'Upisana',
      'GDPR': false,
    };

    FirebaseFirestore.instance.collection('Clanica').add(newMember);

    Navigator.of(context).pop();
  }

  Widget CustomTextField(TextEditingController controller, String? label) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.normal, color: Colors.black),
          border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(15))),
          contentPadding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
        ),
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
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
              'Dodaj novu članicu',
              style: TextStyle(
                  color: Colors.purple,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
                child: SingleChildScrollView(
              child: Column(
                children: [
                  CustomTextField(imeController, 'Ime'),
                  CustomTextField(prezimeController, 'Prezime'),
                  CustomTextField(oibController, 'OIB'),
                  CustomTextField(datumRodenjaController, 'Datum rođenja'),
                  CustomTextField(adresaController, 'Adresa'),
                  CustomTextField(mailController, 'Email'),
                  CustomTextField(
                      mobRoditeljaController, 'Broj mobitela roditelja'),
                  CustomTextField(
                      mobClaniceController, 'Broj mobitela članice'),
                  CustomTextField(
                      cijenaClanarineController, 'Cijena članarine'),
                  CustomTextField(
                      brojIskazniceController, 'Broj natjecateljske iskaznice'),
                  CustomTextField(
                      godinaPreregController, 'Godina preregistracije'),
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
                        'Dječji sastav',
                        'Kadet',
                        'Junior',
                        'Senior',
                        'Veteran'
                      ].map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            )),
            GestureDetector(
              onTap: saveMemberToFirestore,
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
                      'Dodaj članicu',
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
