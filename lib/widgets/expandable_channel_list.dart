import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/channels.dart';
import 'package:web_app/screens/channel_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExpandableChannelList extends StatefulWidget {
  const ExpandableChannelList({super.key});

  @override
  State<ExpandableChannelList> createState() => _ExpandableChannelListState();
}

class _ExpandableChannelListState extends State<ExpandableChannelList> {
  final List<QueryDocumentSnapshot> _channels = [];
  late final StreamSubscription _subscription;
  Map<String, List<SubCategory>> _channelSubcategories = {};
  Map<String, bool> _expandedChannels = {};
  String? _selectedChannelId;
  String? _selectedSubcategoryId;
  
  // This is a static variable to persist expansion state across widget rebuilds
  static final Map<String, bool> _persistentExpandedState = {};

  @override
  void initState() {
    super.initState();
    
    // Initialize expanded channels from persistent state
    _expandedChannels = Map<String, bool>.from(_persistentExpandedState);
    
    // Start loading channels
    _loadChannels();
    
    debugPrint('ExpandableChannelList initState. Persistent expanded state: $_persistentExpandedState');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check for selected channel from route
    _checkSelectedChannel(context);
  }
  
  void _loadChannels() {
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
    }, onError: (error) {
      debugPrint("Error fetching channels: $error");
    });
  }

  // Check for selected channel from route
  void _checkSelectedChannel(BuildContext context) {
    // Try to get the current route arguments to identify the selected channel
    final route = ModalRoute.of(context);
    if (route != null && route.settings.arguments != null) {
      final args = route.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        final channelId = args['channelId'] as String?;
        final subcategoryId = args['subcategoryId'] as String?;
        
        if (channelId != null) {
          setState(() {
            _selectedChannelId = channelId;
            _selectedSubcategoryId = subcategoryId;
            
            // Set the expansion state for the selected channel
            _expandedChannels[channelId] = true;
            _persistentExpandedState[channelId] = true;
          });
          
          debugPrint('Selected channel from route: $_selectedChannelId, subcategory: $_selectedSubcategoryId');
        }
      }
    }
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
            
            // Initialize expanded state from the persistent store or default to false
            if (!_expandedChannels.containsKey(channelId)) {
              _expandedChannels[channelId] = _persistentExpandedState[channelId] ?? false;
            }
            
            // Auto-expand selected channel
            if (_selectedChannelId == channelId) {
              _expandedChannels[channelId] = true;
              _persistentExpandedState[channelId] = true;
              debugPrint('Auto-expanding selected channel: $channelId');
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
    // First update the state to ensure the UI will reflect these changes 
    // the next time this widget is rendered
    setState(() {
      _selectedChannelId = channel.id;
      _selectedSubcategoryId = subcategory?.id;
      
      // Always expand the selected channel
      _expandedChannels[channel.id] = true;
      _persistentExpandedState[channel.id] = true;
    });
    
    // Make sure the static variable gets updated too
    _persistentExpandedState[channel.id] = true;
    
    debugPrint('Navigating to channel: ${channel.id}, subcategory: ${subcategory?.id}');
    debugPrint('Channel expansion state: ${_persistentExpandedState[channel.id]}');
    
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        settings: RouteSettings(
          arguments: {
            'channelId': channel.id,
            'subcategoryId': subcategory?.id,
          },
        ),
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => ChannelPage(
          selectedChannel: channel,
          selectedSubcategoryId: subcategory?.id,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  // Toggle channel expansion
  void _toggleChannelExpansion(String channelId) {
    final newState = !(_expandedChannels[channelId] ?? false);
    setState(() {
      _expandedChannels[channelId] = newState;
      _persistentExpandedState[channelId] = newState;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator if no channels are yet fetched
    if (_channels.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 50,
          height: 50,
          child: CircularProgressIndicator(strokeWidth: 4),
        ),
      );
    }
    
    // Build the list with channels and subcategories
    List<Widget> listItems = [];
    
    for (var channelDoc in _channels) {
      final channelId = channelDoc.id;
      final data = channelDoc.data() as Map<String, dynamic>;
      final isExpanded = _expandedChannels[channelId] ?? false;
      final isSelected = _selectedChannelId == channelId && _selectedSubcategoryId == null;
      
      // Add the channel tile
      listItems.add(
        Container(
          color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
          child: ListTile(
            leading: InkWell(
              onTap: () => _toggleChannelExpansion(channelId),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            title: Text(
              data['name'] ?? '',
              style: TextStyle(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: data['description'] != null && data['description'].toString().isNotEmpty
              ? Text(
                  data['description'] ?? '',
                  style: const TextStyle(color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
            dense: true,
            onTap: () {
              // Create channel object
              final channel = Channel(
                id: channelId,
                name: data['name'] ?? '',
                approved: data['approved'] ?? false,
                description: data['description'],
              );
              
              // First toggle the expansion
              _toggleChannelExpansion(channelId);
              
              // Then navigate to the channel
              _navigateToChannel(channel);
            },
          ),
        ),
      );
      
      // If expanded, add subcategories
      if (isExpanded && _channelSubcategories.containsKey(channelId)) {
        final subcategories = _channelSubcategories[channelId] ?? [];
        
        if (subcategories.isEmpty) {
          // Show a message if there are no subcategories
          listItems.add(
            const Padding(
              padding: EdgeInsets.only(left: 50.0, top: 4.0, bottom: 4.0),
              child: Text(
                'No subcategories',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          );
        } else {
          // Add all subcategories
          for (var subcategory in subcategories) {
            final isSubcategorySelected = _selectedChannelId == channelId && _selectedSubcategoryId == subcategory.id;
            
            listItems.add(
              Container(
                color: isSubcategorySelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
                margin: const EdgeInsets.only(left: 25.0),
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

  void _showCreateChannelDialog(BuildContext context) {
    // Create temporary controllers
    final TextEditingController channelNameController = TextEditingController();
    final TextEditingController channelDescriptionController = TextEditingController();

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
              decoration: const InputDecoration(labelText: 'Channel Description'),
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
                    const SnackBar(content: Text('Please sign in to create a channel')),
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
