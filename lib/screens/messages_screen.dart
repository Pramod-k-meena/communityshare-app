import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:web_app/widgets/chat.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  bool _isLoading = true;
  List<Map<String, dynamic>> _conversations = [];
  Map<String, dynamic>? _selectedConversation;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    if (currentUserId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    try {
      // print('DEBUG: Loading conversations for user: $currentUserId');
      // Get user's messages collection
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('messages')
          .orderBy('lastMessageTime', descending: true)
          .get();

      // print('DEBUG: Found ${messagesSnapshot.docs.length} message documents');

      final List<Map<String, dynamic>> conversations = [];

      // Process each conversation
      for (var doc in messagesSnapshot.docs) {
        if (doc.id == 'info') {
          // print('DEBUG: Skipping info document');
          continue; // Skip the info document
        }

        final data = doc.data();
        // print('DEBUG: Processing conversation: ${doc.id}');
        // print('DEBUG: Data: $data');

        // Use the name that was saved with the conversation rather than fetching again
        String otherUserName = data['otherUserName'] ?? 'User';

        // Only if the name is still 'User', try to fetch it again
        if (otherUserName == 'User') {
          final otherUserId = data['otherUserId'];
          //print('DEBUG: No saved name, fetching name for: $otherUserId');

          // If the other user ID is known (not "unknown"), try to fetch their name
          if (otherUserId != 'unknown') {
            try {
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(otherUserId)
                  .get();
              if (userDoc.exists) {
                otherUserName = userDoc.data()?['displayName'] ?? 'User';
                //print('DEBUG: Found name: $otherUserName');
                // Update the saved name for future use
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUserId)
                    .collection('messages')
                    .doc(doc.id)
                    .update({'otherUserName': otherUserName});
              }
            } catch (e) {
              print('Error fetching user name: $e');
            }
          } else {
            // If the other user is "unknown", try to find item owner
            try {
              final itemId = data['itemId'];
              //print('DEBUG: Trying to find owner name for item: $itemId');
              otherUserName = await getOwnerNameForItem(itemId);
              // If found, update the conversation record
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUserId)
                  .collection('messages')
                  .doc(doc.id)
                  .update({'otherUserName': otherUserName});
            } catch (e) {
              print('ERROR finding item owner: $e');
            }
          }
        }

        conversations.add({
          'conversationId': data['conversationId'],
          'otherUserId': data['otherUserId'],
          'otherUserName': otherUserName,
          'lastMessage': data['lastMessage'],
          'lastMessageTime': data['lastMessageTime'],
          'itemId': data['itemId'],
          'itemTitle': data['itemTitle'],
          'unreadCount': data['unreadCount'] ?? 0,
        });
      }

      if (mounted) {
        setState(() {
          _conversations = conversations;
          _isLoading = false;
          // Set the first conversation as selected if available
          if (conversations.isNotEmpty) {
            _selectedConversation = conversations[0];
            _markConversationAsRead(_selectedConversation!);
          }
        });
      }
    } catch (e) {
      print('Error loading conversations: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<String> getOwnerNameForItem(String itemId) async {
    try {
      // First try to get the item
      final itemDoc = await FirebaseFirestore.instance
          .collectionGroup('items')
          .where(FieldPath.documentId, isEqualTo: itemId)
          .get();

      if (itemDoc.docs.isNotEmpty) {
        final data = itemDoc.docs.first.data();

        // If owner name is already stored with the item
        if (data['ownerName'] != null) {
          return data['ownerName'];
        }

        // If we have ownerId but no name, look it up
        if (data['ownerId'] != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(data['ownerId'])
              .get();

          if (userDoc.exists) {
            return userDoc.data()?['name'] ?? 'Unknown User';
          }
        }
      }

      return 'Unknown User';
    } catch (e) {
      debugPrint('Error finding owner name: $e');
      return 'Unknown User';
    }
  }

  void _selectConversation(Map<String, dynamic> conversation) {
    setState(() {
      _selectedConversation = conversation;
    });
    _markConversationAsRead(conversation);
  }

  Future<void> _markConversationAsRead(
      Map<String, dynamic> conversation) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('messages')
          .doc(conversation['conversationId'])
          .update({'unreadCount': 0});

      // Update local state to reflect read status
      setState(() {
        final index = _conversations.indexWhere(
            (conv) => conv['conversationId'] == conversation['conversationId']);
        if (index != -1) {
          _conversations[index]['unreadCount'] = 0;
        }
      });
    } catch (e) {
      print('Error updating unread count: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: const Color(0xFFA76D4B),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : currentUserId == null
              ? const Center(child: Text('Please sign in to view messages'))
              : Row(
                  children: [
                    // Left panel - Conversation list
                    Container(
                      width: 300,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          right: BorderSide(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                      ),
                      child: _conversations.isEmpty
                          ? const Center(child: Text('No messages yet'))
                          : ListView.builder(
                              itemCount: _conversations.length,
                              itemBuilder: (context, index) {
                                final conversation = _conversations[index];
                                final timestamp =
                                    conversation['lastMessageTime']
                                        as Timestamp?;
                                final formattedTime = timestamp != null
                                    ? DateFormat('MMM d, h:mm a')
                                        .format(timestamp.toDate())
                                    : 'Recent';

                                final isSelected = _selectedConversation !=
                                        null &&
                                    _selectedConversation!['conversationId'] ==
                                        conversation['conversationId'];

                                return Container(
                                  color: isSelected
                                      ? Colors.grey.shade200
                                      : Colors.transparent,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFFA76D4B),
                                      child: Text(
                                        conversation['otherUserName']
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    ),
                                    title: Text(
                                      conversation['otherUserName'],
                                      style: TextStyle(
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'About: ${conversation['itemTitle']}',
                                          style: const TextStyle(
                                            fontStyle: FontStyle.italic,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          conversation['lastMessage'],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          formattedTime,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        if (conversation['unreadCount'] > 0)
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFA76D4B),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              '${conversation['unreadCount']}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    onTap: () =>
                                        _selectConversation(conversation),
                                  ),
                                );
                              },
                            ),
                    ),

                    // Right panel - Selected conversation
                    Expanded(
                      child: _selectedConversation == null
                          ? const Center(
                              child: Text(
                                  'Select a conversation to start chatting'),
                            )
                          : Column(
                              children: [
                                // Chat header
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.2),
                                        spreadRadius: 1,
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor:
                                            const Color(0xFFA76D4B),
                                        radius: 20,
                                        child: Text(
                                          _selectedConversation![
                                                  'otherUserName']
                                              .substring(0, 1)
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _selectedConversation![
                                                'otherUserName'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            'Item: ${_selectedConversation!['itemTitle']}',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Chat messages
                                Expanded(
                                  child: ChatWidget(
                                    ownerId:
                                        _selectedConversation!['otherUserId'],
                                    itemId: _selectedConversation!['itemId'],
                                    itemTitle:
                                        _selectedConversation!['itemTitle'],
                                    currentUserId: currentUserId!,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
    );
  }
}
