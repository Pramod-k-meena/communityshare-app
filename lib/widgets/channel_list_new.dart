import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/channels.dart';
import 'package:web_app/screens/channel_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChannelList extends StatefulWidget {
  const ChannelList({super.key});

  @override
  State<ChannelList> createState() => _ChannelListState();
}

class _ChannelListState extends State<ChannelList> {
  final List<QueryDocumentSnapshot> _channels = [];
  late final StreamSubscription _subscription;
  Map<String, List<SubCategory>> _channelSubcategories = {};
  Map<String, bool> _expandedChannels = {};
  String? _selectedChannelId;
  String? _selectedSubcategoryId; // Track the selected subcategory

  @override
  void initState() {
    super.initState();
    // Listen and cache channels from Firestore
    _subscription = FirebaseFirestore.instance
        .collection('channels')
        .where('approved', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _channels
          ..clear()
          ..addAll(snapshot.docs);
      });
      // Load subcategories for each channel
      _loadAllSubcategories();
      
      // If we have a channel selected (from the ChannelPage), ensure it starts expanded
      if (_selectedChannelId != null) {
        setState(() {
          _expandedChannels[_selectedChannelId!] = true;
        });
      }
    }, onError: (error) {
      debugPrint("Error fetching channels: $error");
    });
  }

  // Load subcategories for all channels
  Future<void> _loadAllSubcategories() async {
    for (var channelDoc in _channels) {
      final channelId = channelDoc.id;
      final channelData = channelDoc.data() as Map<String, dynamic>;
      
      // Create a Channel object
      final channel = Channel(
        id: channelId,
        name: channelData['name'] ?? '',
        approved: channelData['approved'] ?? false,
        description: channelData['description'],
      );
      
      // Fetch subcategories
      try {
        final subcategories = await channel.fetchSubCategories();
        if (mounted) {
          setState(() {
            _channelSubcategories[channelId] = subcategories;
            // Initialize expanded state if not already set
            if (!_expandedChannels.containsKey(channelId)) {
              _expandedChannels[channelId] = false;
            }
          });
        }
      } catch (e) {
        debugPrint("Error fetching subcategories for channel $channelId: $e");
      }
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  // Navigate to channel page with selected channel and optionally a selected subcategory
  void _navigateToChannel(Channel channel, {SubCategory? subcategory}) {
    // Store the current state before navigating
    final currentExpandedState = Map<String, bool>.from(_expandedChannels);
    
    setState(() {
      _selectedChannelId = channel.id;
      _selectedSubcategoryId = subcategory?.id;
    });
    
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          // Pass the callback to restore expanded state after navigation
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _expandedChannels = currentExpandedState;
              });
            }
          });
          
          return ChannelPage(
            selectedChannel: channel,
            selectedSubcategoryId: subcategory?.id,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  // Toggle channel expansion without affecting navigation
  void _toggleChannelExpansion(String channelId) {
    setState(() {
      _expandedChannels[channelId] = !(_expandedChannels[channelId] ?? false);
    });
    
    // If we're collapsing the currently selected channel, keep its selection state
    if (!(_expandedChannels[channelId] ?? false) && _selectedChannelId == channelId) {
      setState(() {
        _selectedSubcategoryId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator if no channels are yet fetched.
    if (_channels.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 50,
          height: 50,
          child: CircularProgressIndicator(strokeWidth: 4),
        ),
      );
    }
    
    // Build the expanded list with channels and subcategories
    List<Widget> listItems = [];
    
    for (var channelDoc in _channels) {
      final channelId = channelDoc.id;
      final data = channelDoc.data() as Map<String, dynamic>;
      final isExpanded = _expandedChannels[channelId] ?? false;
      final isSelected = _selectedChannelId == channelId && _selectedSubcategoryId == null;
      
      // Add the channel tile
      listItems.add(
        ListTile(
          leading: IconButton(
            icon: Icon(
              isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
              color: Colors.white,
            ),
            onPressed: () {
              // Only toggle expansion when clicking on the arrow icon
              _toggleChannelExpansion(channelId);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          title: Text(
            data['name'] ?? '',
            style: TextStyle(
              color: Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Text(
            data['description'] ?? '',
            style: const TextStyle(color: Colors.white70),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            // When clicking on a channel title, ensure it's expanded
            // This allows users to see subcategories of the current channel
            if (!(_expandedChannels[channelId] ?? false)) {
              setState(() {
                _expandedChannels[channelId] = true;
              });
            }
            
            // Navigate to channel page to show all items
            final channel = Channel(
              id: channelId,
              name: data['name'] ?? '',
              approved: data['approved'] ?? false,
              description: data['description'],
            );
            _navigateToChannel(channel);
          },
        ),
      );
      
      // If expanded, add subcategories
      if (isExpanded && _channelSubcategories.containsKey(channelId)) {
        final subcategories = _channelSubcategories[channelId] ?? [];
        
        for (var subcategory in subcategories) {
          final isSubcategorySelected = _selectedChannelId == channelId && _selectedSubcategoryId == subcategory.id;
          
          listItems.add(
            Padding(
              padding: const EdgeInsets.only(left: 25.0),
              child: ListTile(
                leading: const Icon(Icons.subdirectory_arrow_right, color: Colors.white70, size: 16),
                title: Text(
                  subcategory.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: isSubcategorySelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                dense: true,
                onTap: () {
                  // Navigate to channel with filtered subcategory
                  final channel = Channel(
                    id: channelId,
                    name: data['name'] ?? '',
                    approved: data['approved'] ?? false,
                    description: data['description'],
                  );
                  _navigateToChannel(channel, subcategory: subcategory);
                },
              ),
            ),
          );
        }
      }
    }
    
    // Add the "Request New Channel" item at the end
    listItems.add(
      ListTile(
        leading: const Icon(Icons.add, color: Colors.green),
        title: const Text(
          'Request New Channel',
          style: TextStyle(color: Colors.white),
        ),
        onTap: () => _showCreateChannelDialog(context),
      ),
    );
    
    return ListView(
      children: listItems,
    );
  }

  Future<bool> canUserCreateChannel(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        return false;
      }

      final userData = userDoc.data()!;
      final lastRequestTime = userData['lastChannelRequestTime'];

      // If user has never requested a channel or lastRequestTime is null
      if (lastRequestTime == null) {
        return true;
      }

      // Convert Firestore Timestamp to DateTime
      final lastRequest = (lastRequestTime as Timestamp).toDate();
      final now = DateTime.now();

      // Calculate the difference in days
      final difference = now.difference(lastRequest).inDays;

      // Allow if 7 or more days have passed
      return difference >= 7;
    } catch (e) {
      print('Error checking channel request eligibility: $e');
      return false;
    }
  }

  void _showCreateChannelDialog(BuildContext context) {
    // Create temporary controllers
    final TextEditingController channelNameController = TextEditingController();
    final TextEditingController channelDescriptionController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Channel Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: channelNameController,
              decoration: const InputDecoration(labelText: 'Channel Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: channelDescriptionController,
              decoration:
                  const InputDecoration(labelText: 'Channel Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (channelNameController.text.isNotEmpty) {
                // Check if user can create a channel
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please sign in to create a channel')),
                  );
                  Navigator.pop(context);
                  return;
                }

                // Only proceed if the user is eligible
                try {
                  await FirebaseFirestore.instance.collection('channels').add({
                    'name': channelNameController.text,
                    'description': channelDescriptionController.text,
                    'approved': false,
                    'timestamp': FieldValue.serverTimestamp(),
                    'requestedBy': user.uid, // Track who requested it
                  });

                  // Update the lastChannelRequestTime after successful submission
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .update({
                    'lastChannelRequestTime': FieldValue.serverTimestamp()
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Channel request sent')));
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Error creating channel request: $e')));
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
