import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:web_app/models/item.dart';
import 'package:web_app/widgets/borrow_request.dart';
import 'package:web_app/widgets/item_card.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final User? currentUser = FirebaseAuth.instance.currentUser;
  String _userName = 'User';
  int _ecoPoints = 0;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Load user data from Firestore
  Future<void> _loadUserData() async {
    try {
      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .get();

        if (userDoc.exists) {
          if (mounted) {
            // Get the display name from Firestore or Firebase Auth
            setState(() {
              _userName = userDoc.data()?['displayName'] ??
                  currentUser!.displayName ??
                  'User';
              _ecoPoints = userDoc.data()?['ecoPoints'] ?? 0;
              _isLoadingUser = false;
            });
          }
        } else {
          // If user document doesn't exist in Firestore, use Auth display name
          if (mounted) {
            setState(() {
              _userName = currentUser!.displayName ?? 'User';
              _isLoadingUser = false;
            });
          }
        }
      } else {
        // Handle not signed in case
        if (mounted) {
          setState(() {
            _isLoadingUser = false;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoadingUser = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view your profile')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: const Color(0xFFA76D4B),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'My Lent Items'),
            Tab(text: 'Approval Requests'),
          ],
        ),
      ),
      body: _isLoadingUser
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // User profile info card
                // Container(
                //   width: double.infinity,
                //   padding: const EdgeInsets.all(16),
                //   color: const Color(0xFFEBE4DF),
                //   child: Column(
                //     children: [
                //       const CircleAvatar(
                //         radius: 40,
                //         backgroundColor: Color(0xFFA76D4B),
                //         child: Icon(
                //           Icons.person,
                //           size: 60,
                //           color: Colors.white,
                //         ),
                //       ),
                //       const SizedBox(height: 8),
                //       Text(
                //         _userName,
                //         style: const TextStyle(
                //           fontSize: 20,
                //           fontWeight: FontWeight.bold,
                //         ),
                //       ),
                //       const SizedBox(height: 4),
                //       Row(
                //         mainAxisAlignment: MainAxisAlignment.center,
                //         children: [
                //           const Icon(Icons.eco, color: Colors.green),
                //           const SizedBox(width: 4),
                //           Text(
                //             '$_ecoPoints eco points',
                //             style: const TextStyle(
                //               fontSize: 16,
                //               color: Colors.green,
                //             ),
                //           ),
                //         ],
                //       ),
                //     ],
                //   ),
                // ),
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // My Lent Items Tab
                      _buildLentItemsTab(),

                      // Approval Requests Tab
                      SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pending Borrow Requests',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              // Reuse the BorrowApprovalSection widget
                              const BorrowApprovalSection(),

                              // Add the request history section
                              const BorrowRequestHistory(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // Tab to display user's lent items
  Widget _buildLentItemsTab() {
    // Option 1: Use a simple query approach instead of collectionGroup
    // This queries each channel's items collection separately
    return FutureBuilder<List<Item>>(
      future: _fetchUserItems(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return const Center(
            child: Text('You haven\'t lent any items yet.'),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width < 600 ? 2 : 4,
            childAspectRatio: 1.0,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ItemCard(
              item: item,
              channelId: item.channelId,
              isProfile: true, // To indicate this is in profile view
            );
          },
        );
      },
    );
  }

  // Helper method to fetch user's items across all channels
  Future<List<Item>> _fetchUserItems() async {
    if (currentUser == null) return [];

    try {
      // First get all channels
      final channelsSnapshot =
          await FirebaseFirestore.instance.collection('channels').get();

      List<Item> allItems = [];

      // For each channel, query its items collection for items owned by the current user
      for (var channel in channelsSnapshot.docs) {
        final itemsSnapshot = await FirebaseFirestore.instance
            .collection('channels')
            .doc(channel.id)
            .collection('items')
            .where('ownerId', isEqualTo: currentUser!.uid)
            .get();

        // Convert the documents to Item objects
        final channelItems = itemsSnapshot.docs.map((doc) {
          final data = doc.data();
          return Item(
            id: doc.id,
            title: data['title'] ?? '',
            imageUrl: data['imageUrl'] ?? '',
            distance: (data['distance'] ?? 0).toDouble(),
            channelId: data['channelId'] ?? channel.id,
            ownerId: data['ownerId'],
            ownerName: data['ownerName'],
            subcategory: data['subcategory'],
            itemCategory: data['itemCategory'],
          );
        }).toList();

        allItems.addAll(channelItems);
      }

      return allItems;
    } catch (e) {
      debugPrint('Error fetching user items: $e');
      return [];
    }
  }
}
