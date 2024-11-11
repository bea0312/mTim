import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'member_info_page.dart';

class HomePageContent extends StatefulWidget {
  const HomePageContent({super.key});

  @override
  _HomePageContentState createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  String? userTim;
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();
  String searchQuery = "";
  final int currentYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    fetchUserTim();
    searchController.addListener(_onSearchChanged);
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
              setState(() {
                userTim = userData['Tim'];
              });
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching user Tim: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    setState(() {
      searchQuery = searchController.text.toLowerCase();
    });
  }

  String normalizeCroatianString(String input) {
    return input
        .replaceAll('Ć', 'D')
        .replaceAll('Đ', 'D')
        .replaceAll('Ž', 'Z')
        .replaceAll('Š', 'S')
        .replaceAll('Č', 'C')
        .replaceAll('LJ', 'Lj')
        .replaceAll('NJ', 'Nj')
        .toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : userTim == null
              ? const Center(child: Text('Not authorized to view this content'))
              : Center(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'Upiši ime ili prezime...',
                            hintStyle: TextStyle(color: Colors.purple[100]),
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection("Clanica")
                              .where('Tim', isEqualTo: userTim)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              final filteredDocs = snapshot.data?.docs
                                  .where((doc) =>
                                      doc['Uloga'] != 'Trener' &&
                                      doc['Status'] != 'Ispis')
                                  .toList();
                              filteredDocs?.sort((a, b) {
                                final aPrezime =
                                    normalizeCroatianString(a['Prezime'] ?? '');
                                final bPrezime =
                                    normalizeCroatianString(b['Prezime'] ?? '');
                                return aPrezime.compareTo(bPrezime);
                              });

                              final members = filteredDocs?.where((member) {
                                final memberData =
                                    member.data() as Map<String, dynamic>;
                                final ime = memberData['Ime'].toLowerCase();
                                final prezime =
                                    memberData['Prezime'].toLowerCase();
                                return ime.contains(searchQuery) ||
                                    prezime.contains(searchQuery);
                              }).toList();

                              if (members == null || members.isEmpty) {
                                return const Center(
                                  child: Text('No members found.'),
                                );
                              }

                              return ListView.builder(
                                itemCount: members.length,
                                itemBuilder: (context, index) {
                                  final member = members[index];
                                  final memberData =
                                      member.data() as Map<String, dynamic>;
                                  final docId = member.id;
                                  final godinaPreregistracije =
                                      memberData['Godina preregistracije'];
                                  bool isCurrentYearWarning = false;
                                  if (godinaPreregistracije != null &&
                                      godinaPreregistracije.isNotEmpty) {
                                    final int? godinaPreregistracijeInt =
                                        int.tryParse(godinaPreregistracije);
                                    if (godinaPreregistracijeInt != null &&
                                        godinaPreregistracijeInt ==
                                            currentYear) {
                                      isCurrentYearWarning = true;
                                    }
                                  }
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => MemberInfoPage(
                                            memberData: memberData,
                                            docId: docId,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Card(
                                        color: Colors.purple[100],
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(15.0),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    '${memberData['Ime']} ${memberData['Prezime']}',
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  if (isCurrentYearWarning)
                                                    const Icon(
                                                      Icons.warning,
                                                      color: Colors.red,
                                                      size: 24.0,
                                                    ),
                                                ],
                                              ),
                                              if (godinaPreregistracije != null)
                                                Text(
                                                  'Godina preregistracije: $godinaPreregistracije',
                                                  style: const TextStyle(
                                                      fontSize: 16),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            } else if (snapshot.hasError) {
                              return Center(
                                child: Text('Error: ${snapshot.error}'),
                              );
                            }
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }
}
