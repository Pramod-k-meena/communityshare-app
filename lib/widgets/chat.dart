import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class ChatWidget extends StatefulWidget {
  final String ownerId;
  final String itemId;
  final String itemTitle;
  final String currentUserId;
  // New parameter to control image size; default to 350 for messages screen
  final double imageSize;

  const ChatWidget({
    super.key,
    required this.ownerId,
    required this.itemId,
    required this.itemTitle,
    required this.currentUserId,
    this.imageSize = 350, // Default image size for messages screen
  });

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isUploadingImage = false;
  final ImagePicker _picker = ImagePicker();

  // Create a unique conversation ID that's the same regardless of who initiates
  String get _conversationId {
    // Sort IDs alphabetically to ensure the same ID is generated for both users
    List<String> ids = [widget.currentUserId, widget.ownerId];
    ids.sort();
    return '${ids[0]}_${ids[1]}_${widget.itemId}';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    try {
      // Create message data (adjust fields as needed)
      final messageData = {
        'text': messageText,
        'senderId': widget.currentUserId,
        'receiverId': widget.ownerId,
        'timestamp': FieldValue.serverTimestamp(),
        'itemId': widget.itemId,
        'itemTitle': widget.itemTitle,
        'read': false,
      };

      // Add message to conversation collection
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(_conversationId)
          .collection('messages')
          .add(messageData);

      // Update conversation metadata (if needed)
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(_conversationId)
          .set({
        'participants': [widget.currentUserId, widget.ownerId],
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'itemId': widget.itemId,
        'itemTitle': widget.itemTitle,
        'unreadCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      // Use a post frame callback to scroll after the UI has updated,
      // without triggering a full rebuild that causes flicker.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0.0);
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error sending message: $e')));
    } finally {
      // Request focus back to the text field.
      _messageFocusNode.requestFocus();
    }
  }

  // Add this method to pick an image
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        await _uploadAndSendImage(pickedFile);
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: $e')),
      );
    }
  }

  // Add this method to upload and send an image
  Future<void> _uploadAndSendImage(XFile imageFile) async {
    setState(() {
      _isUploadingImage = true;
    });

    try {
      // Create unique filename
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${widget.currentUserId}.jpg';
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child(_conversationId)
          .child(fileName);

      // Upload the file
      UploadTask uploadTask;
      if (kIsWeb) {
        // Handle web upload
        uploadTask = storageRef.putData(
          await imageFile.readAsBytes(),
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        // Handle mobile upload
        uploadTask = storageRef.putFile(File(imageFile.path));
      }

      // Get download URL after upload completes
      final TaskSnapshot taskSnapshot = await uploadTask;
      final String imageUrl = await taskSnapshot.ref.getDownloadURL();

      // Send message with image URL
      await _sendMessageWithImage(imageUrl);
    } catch (e) {
      print('Error uploading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
    } finally {
      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  // Add this method to send a message with an image
  Future<void> _sendMessageWithImage(String imageUrl) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Create message data with image
      final messageData = {
        'text': '',
        'imageUrl': imageUrl,
        'senderId': widget.currentUserId,
        'receiverId': widget.ownerId,
        'timestamp': FieldValue.serverTimestamp(),
        'itemId': widget.itemId,
        'itemTitle': widget.itemTitle,
        'read': false,
      };

      // Reference to the conversation document
      final conversationRef = FirebaseFirestore.instance
          .collection('conversations')
          .doc(_conversationId);

      // Add message to conversation
      await conversationRef.collection('messages').add(messageData);

      // Update conversation metadata
      await conversationRef.set({
        'participants': [widget.currentUserId, widget.ownerId],
        'lastMessage': '📷 Image',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'itemId': widget.itemId,
        'itemTitle': widget.itemTitle,
        'unreadCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      // Update current user's messages collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .collection('messages')
          .doc(_conversationId)
          .set({
        'conversationId': _conversationId,
        'otherUserId': widget.ownerId,
        'otherUserName': 'User', // You might want to fetch actual name
        'lastMessage': '📷 Image',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'itemId': widget.itemId,
        'itemTitle': widget.itemTitle,
        'unreadCount': 0,
      }, SetOptions(merge: true));

      // Update recipient's messages collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.ownerId)
          .collection('messages')
          .doc(_conversationId)
          .set({
        'conversationId': _conversationId,
        'otherUserId': widget.currentUserId,
        'otherUserName':
            FirebaseAuth.instance.currentUser?.displayName ?? 'User',
        'lastMessage': '📷 Image',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'itemId': widget.itemId,
        'itemTitle': widget.itemTitle,
        'unreadCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      print('ERROR in _sendMessageWithImage: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending image: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Messages area
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('conversations')
                .doc(_conversationId)
                .collection('messages')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Error loading messages'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = snapshot.data!.docs;

              return ListView.builder(
                controller: _scrollController,
                reverse: true, // show newest messages at the bottom
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final data = messages[index].data() as Map<String, dynamic>;
                  final isMe = data['senderId'] == widget.currentUserId;
                  final timestamp = data['timestamp'] as Timestamp?;
                  final time = timestamp != null
                      ? DateFormat('h:mm a').format(timestamp.toDate())
                      : '';

                  final hasImage =
                      data['imageUrl'] != null && data['imageUrl'] != '';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: isMe
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (!isMe) ...[
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFFA76D4B),
                            child: const Icon(Icons.person,
                                size: 20, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.6,
                              ),
                              padding: hasImage
                                  ? const EdgeInsets.all(4)
                                  : const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? const Color(0xFFB37B5F)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: hasImage
                                  ? Container(
                                      // Use the widget.imageSize parameter here
                                      constraints: BoxConstraints(
                                        maxWidth: widget.imageSize,
                                        maxHeight: widget.imageSize,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          data['imageUrl'],
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child,
                                              loadingProgress) {
                                            if (loadingProgress == null) {
                                              return child;
                                            }
                                            return Center(
                                              child: CircularProgressIndicator(
                                                value: loadingProgress
                                                            .expectedTotalBytes !=
                                                        null
                                                    ? loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        (loadingProgress
                                                                .expectedTotalBytes ??
                                                            1)
                                                    : null,
                                              ),
                                            );
                                          },
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Container(
                                              width: widget.imageSize,
                                              height: widget.imageSize,
                                              color: Colors.grey[300],
                                              child: const Icon(
                                                Icons.broken_image,
                                                size: 40,
                                                color: Colors.grey,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    )
                                  : Text(
                                      data['text'] ?? '',
                                      style: TextStyle(
                                        color:
                                            isMe ? Colors.white : Colors.black,
                                      ),
                                    ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: 4, left: 4, right: 4),
                              child: Text(
                                time,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFFB37B5F),
                            child: Text(
                              _userName.isNotEmpty ? _userName[0] : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Message input area
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          color: Colors.white,
          child: Row(
            children: [
              // Add image picker button
              IconButton(
                icon: const Icon(Icons.photo),
                color: const Color(0xFFB37B5F),
                onPressed: _isUploadingImage ? null : _pickImage,
              ),

              // Existing text field
              Expanded(
                child: TextField(
                  controller: _messageController,
                  focusNode: _messageFocusNode, // assign FocusNode here
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),

              const SizedBox(width: 8),

              // Send button with loading indicator for both text and image uploads
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFB37B5F),
                child: IconButton(
                  icon: _isLoading || _isUploadingImage
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                  onPressed: (_isLoading ||
                          _isUploadingImage ||
                          _messageController.text.trim().isEmpty)
                      ? null
                      : _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Get the first letter of current user's name
  String get _userName {
    return FirebaseAuth.instance.currentUser?.displayName ?? '';
  }
}
