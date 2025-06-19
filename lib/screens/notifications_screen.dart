import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:web_app/widgets/chat.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Future<void> _markAllAsRead(
      String userId, List<QueryDocumentSnapshot> notifications) async {
    for (var doc in notifications) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['read'] == false) {
        await doc.reference.update({'read': true});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Not signed in')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color(0xFFA76D4B),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final notifications = snapshot.data!.docs;
          if (notifications.isEmpty) {
            return const Center(child: Text('No notifications'));
          }

          // Mark unread notifications as read once after getting snapshot data.
          Future.delayed(Duration.zero, () async {
            await _markAllAsRead(currentUser.uid, notifications);
          });

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final data = notifications[index].data() as Map<String, dynamic>;

              // Extract extra fields; adjust keys as per your notification doc.
              final String requestUser = data['requestUser'] ?? 'Unknown User';
              final double distance = data['distance']?.toDouble() ?? 0;
              final String channelName =
                  data['channelName'] ?? 'Unknown Channel';
              final String message = data['message'] ?? 'Notification';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 3,
                child: InkWell(
                  onTap: () {
                    // Open chat pop-up with the request maker.
                    // We pass the requestUserId as ownerId, use requestId as itemId,
                    // and use the notification message as a title placeholder.
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => DraggableScrollableSheet(
                        expand: false,
                        builder: (context, scrollController) => ChatWidget(
                          ownerId: data['requestUserId'] ??
                              '', // chat with request maker
                          itemId: data['requestId'] ??
                              '', // use request id (or a conversation id)
                          itemTitle: data['message'] ?? 'Item Request',
                          currentUserId: currentUser.uid,
                          imageSize:
                              250, // For pop up chat, you can adjust as needed.
                        ),
                      ),
                    );
                  },
                  child: ListTile(
                    title: Text(
                      message,
                      style: const TextStyle(fontSize: 16),
                    ),
                    subtitle: Text(
                      "Requested by: $requestUser\n"
                      "Channel: $channelName\n"
                      "Distance: ${distance.toStringAsFixed(1)} km",
                      style: const TextStyle(fontSize: 14),
                    ),
                    trailing: data['read'] == false
                        ? const Icon(Icons.fiber_new, color: Colors.red)
                        : null,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
