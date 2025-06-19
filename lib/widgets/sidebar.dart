import 'package:flutter/material.dart';
import 'package:web_app/screens/messages_screen.dart';
import 'package:web_app/widgets/expandable_channel_list.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:web_app/screens/revive_and_thrive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:web_app/screens/notifications_screen.dart';
import 'package:web_app/screens/settings_page.dart';
import 'package:web_app/screens/profile_page.dart'; // Add import for ProfilePage

class SidebarWidget extends StatelessWidget {
  final String userName;
  final int ecoPoints;

  const SidebarWidget({
    super.key,
    required this.userName,
    required this.ecoPoints,
  });

  Widget _buildFooterTile(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(title, style: const TextStyle(color: Colors.white)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get currentUser for unread messages stream
    final currentUser = FirebaseAuth.instance.currentUser;
    return Container(
      width: 300,
      color: const Color(0xFFA76D4B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Profile Section - Made clickable to navigate to profile page
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfilePage(),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey,
                    child: Icon(
                      Icons.person,
                      size: 60,
                      color: Color.fromARGB(255, 68, 51, 46),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            const Icon(Icons.eco,
                                color: Colors.green, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '$ecoPoints eco points',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Sign-out button
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    tooltip: 'Sign Out',
                    onPressed: () => _signOut(context),
                  ),
                ],
              ),
            ),
          ),
          // Navigation Items
          if (currentUser != null)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .collection('notifications')
                  .where('read', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                int unreadNotifCount =
                    snapshot.hasData ? snapshot.data!.docs.length : 0;
                return ListTile(
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        unreadNotifCount > 0
                            ? Icons
                                .notifications_active // new icon when unread exists
                            : Icons.notifications, // normal icon
                        color: Colors.white,
                        size: 28,
                      ),
                      if (unreadNotifCount > 0)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '$unreadNotifCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: const Text(
                    'Notifications',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        transitionDuration: const Duration(milliseconds: 300),
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const NotificationsScreen(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                      ),
                    );
                  },
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  dense: true,
                );
              },
            ),
          // Messages navigation with unread icon
          if (currentUser != null)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .collection('messages')
                  .where('read', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                int unreadCount =
                    snapshot.hasData ? snapshot.data!.docs.length : 0;
                return ListTile(
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        unreadCount > 0
                            ? Icons.mark_email_unread
                            : Icons.message,
                        color: Colors.white,
                        size: 28,
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: const Text(
                    'Messages',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MessagesScreen(),
                      ),
                    );
                    // In your MessagesScreen, ensure that when a conversation is opened,
                    // you update the 'read' field on messages so that the count decreases.
                  },
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  dense: true,
                );
              },
            ),
          // const SizedBox(height: 4), // Reduced gap between Messages & Settings
          // Settings navigation - Rename to "Settings" instead of "Profile"
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.white),
            title:
                const Text('Settings', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            dense: true,
          ),
          const SizedBox(height: 4), // Reduced gap between Settings & Channels
          // Channels Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'CHANNELS',
              style:
                  TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
            ),
          ),
          const Expanded(child: ExpandableChannelList()),
          // Footer Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _buildFooterTile('About Us'),
                _buildFooterTile('Green Resources 🌿'),
                _buildFooterTile('Feedback 🤝'),
                _buildFooterTile('Buy us a coffee! ☕'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const ReviveAndThrivePage()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }
}
